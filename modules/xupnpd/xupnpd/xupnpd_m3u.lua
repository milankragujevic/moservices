-- Copyright (C) 2011-2012 Anton Burdinuk
-- clark15b@gmail.com
-- https://tsdemuxer.googlecode.com/svn/trunk/xupnpd

function add_playlists_from_dir(dir_path,playlist,plist)

    local d=util.dir(dir_path)

    if d then
        table.sort(d)
        local tt={}
        for i,j in ipairs(playlist) do
            local path=nil
            if type(j)=='table' then path=j[1] else path=j end
            tt[path]=j
        end

        for i,j in ipairs(d) do
            if string.find(j,'%.m3u$') then
                local fname=dir_path..j
                if not tt[fname] then
                    table.insert(plist,fname)
                    if cfg.debug>0 then print('found unlisted playlist \''..fname..'\'') end
                end
            end
        end
    end
end

function playlist_new_folder(parent,name)
    local child={}
    parent.size=parent.size+1
    child.name=name
    child.objid=parent.objid..'_'..parent.size
    child.parent=parent
    child.size=0
    child.elements={}
    parent.elements[parent.size]=child
    return child
end

function playlist_sort_elements(pls)
    if cfg.sort_files~=true or pls==nil or pls.elements==nil then return end
    table.sort(pls.elements,function(a,b) return string.lower(a.name)<string.lower(b.name) end)
end

function playlist_fix_sub_tree(pls)
    playlist_sort_elements(pls)
    for i,j in ipairs(pls.elements) do
        j.objid=pls.objid..'_'..i
        j.parent=pls

        if j.elements then
            playlist_fix_sub_tree(j)
        else
            j.type=util.getfext(j.url)

            if not mime[j.type] then j.type=cfg.default_mime_type end
        end

    end
end

function playlist_attach(parent,pls)
    parent.size=parent.size+1
    pls.objid=parent.objid..'_'..parent.size
    pls.parent=parent
    parent.elements[parent.size]=pls
end

function reload_playlists()
    playlist_data={}
    playlist_data.name='root'
    playlist_data.objid='0'
    playlist_data.size=0
    playlist_data.elements={}

    local plist=clone_table(playlist)

    add_playlists_from_dir(cfg.playlists_path,playlist,plist)
    if cfg.feeds_path~=cfg.playlists_path then add_playlists_from_dir(cfg.feeds_path,playlist,plist) end

    local pls_folder=playlist_data

    if cfg.group==true then
        pls_folder=playlist_new_folder(playlist_data,'Playlists')
    end

    local groups={}

    for i,j in ipairs(plist) do

        local pls

        if type(j)=='table' then

            if string.find(j[1],'%.m3u$') then pls=m3u.parse(j[1]) else pls=m3u.scan(j[1]) end

            if pls then
                if j[2] then pls.name=j[2] end
                if j[3] then pls.acl=j[3] end
            end
        else
            if string.find(j,'%.m3u$') then pls=m3u.parse(j) else pls=m3u.scan(j) end
        end

        if pls then
            if pls.filesystem then
                playlist_attach(playlist_data,pls)
            else
                playlist_attach(pls_folder,pls)
            end

            if cfg.debug>0 then print('playlist \''..pls.name..'\'') end

            if pls.filesystem then
                playlist_fix_sub_tree(pls)
            else
                local udpxy=nil
                if cfg.udpxy_url then udpxy=cfg.udpxy_url end

                for ii,jj in ipairs(pls.elements) do

                    if udpxy then
                        jj.url=string.gsub(jj.url,'udp://@',udpxy..'/udp/',1)
                        jj.url=string.gsub(jj.url,'rtp://@',udpxy..'/rtp/',1)
                    end

                    if not jj.type then
                        if pls.type then
                            jj.type=pls.type
                        else
                            jj.type=util.getfext(jj.url)
                        end
                    end

                    if pls.plugin and not jj.plugin then jj.plugin=pls.plugin end

                    if pls.dlna_extras and not jj.dlna_extras then jj.dlna_extras=pls.dlna_extras end

                    if not mime[jj.type] then jj.type=cfg.default_mime_type end

                    jj.objid=pls.objid..'_'..ii
                    jj.parent=pls
                    if cfg.debug>1 then print('\''..jj.name..'\' '..jj.url..' <'..jj.type..'>') end

                    if cfg.group==true then
                        local group_title=jj['group-title']
                        if group_title then
                            local group=groups[group_title]
                            if not group then
                                group={}
                                group.name=group_title
                                group.elements={}
                                group.size=0
                                group.virtual=true
                                groups[group_title]=group
                            end

                            local element=clone_table(jj)
                            element.parent=group
                            element.objid=nil
                            group.size=group.size+1
                            group.elements[group.size]=element
                        end
                    end
                end
            end
        end
    end

    if cfg.group==true then
        for i,j in pairs(groups) do

            if cfg.debug>0 then print('group \''..j.name..'\'') end

            playlist_attach(playlist_data,j)

            for ii,jj in ipairs(j.elements) do
                jj.objid=j.objid..'_'..ii
            end
        end
    end

end

function find_playlist_object(s)
    if not s then return nil end

    local pls=nil

    for i in string.gmatch(s,'([^_]+)') do
        if not pls then
            if string.find(i,'^%d+$') then pls=playlist_data else return nil end
        else
            if not pls.elements then return nil end            
            pls=pls.elements[tonumber(i)]
        end
    end
    return pls
end

reload_playlists()

require "open3"
require "etc"
require "json"
class DiskQuota
  def initialize()
  end

  def uncephify(cephdetail)
    return {
      "usage_bytes" => cephdetail["ceph.dir.rbytes"],
      "usage_files" => cephdetail["ceph.dir.rentries"],
      "limit_bytes" => cephdetail["ceph.quota.max_bytes"],
      "limit_files" => cephdetail["ceph.quota.max_files"]
    }
  end

  def unwekaify(wekadetail)
    return {
      "path" => "/mimer/NOBACKUP/groups/" + wekadetail["path"].sub(/\//, ""),
      "title" => "/mimer/NOBACKUP/groups/" + wekadetail["path"].sub(/\//, ""),
      "usage_bytes" => wekadetail["total_bytes"].to_s,
      "limit_bytes" => wekadetail["hard_limit_bytes"].to_s
    }
  end

  def weka_quota(user)
    groups = Etc.enum_for(:group).select{|group| group.mem.include?(user)}
    group_names_wo_pg = groups.map{|group| group.name.sub(/pg_/, "")}
    mimer_quota_file = File.read("/mimer/NOBACKUP/groups/.quota.json")
    quota_json = JSON.parse(mimer_quota_file)
    #my_mimer_details = group_names_wo_pg.select{|group| quota_json.key=}.map{|group| quota_json["/" + group]}
    my_mimer_details = group_names_wo_pg.filter_map{|group| quota_json["/" + group] if quota_json.key?("/" + group)}
    my_storage_details = my_mimer_details.map{|mdetail| unwekaify(mdetail)}
    [my_storage_details, ""]
  end

  def ceph_quota(path)
    res, error = {}, nil
    ceph_xattrs = ["ceph.dir.rbytes",
                   "ceph.dir.rentries",
                   "ceph.quota.max_bytes",
                   "ceph.quota.max_files"]
    ceph_xattrs.each do |attr| 
      cmd = "getfattr --only-values -n #{attr} #{path}"
      stdout_str, stderr_str, status = Open3.capture3(cmd)
      if status.success?
        res.store(attr, stdout_str)
      else
        error = "Command '#{cmd}' exited with error: #{stderr_str}"
      end
    end
    [res, error]
  end

  def get_group_owned_subdirs(user, path)
    groups = Etc.enum_for(:group).select{|group| group.mem.include?(user)}
    group_names = groups.map{|group| group.name}
    group_gids = groups.map{|group| group.gid}
    group_gids.append(1000809)
    dirs = []
    Dir.foreach(path) do |dirname|
      next if dirname == '.' or dirname == '..'
      dir = File.stat("#{path}/#{dirname}")
      if group_gids.include?(dir.gid)
        dirs.append(path + "/" + dirname)
      end
    end
    return dirs
  end

  def disk_quota
    user = Etc.getpwuid.name

    # List of quota data objects to render later
    res_list = []

    # Home directory
    home_path = "/cephyr/users/#{user}"
    home_cephdetails, error_home = ceph_quota(home_path)
    quota_home = uncephify(home_cephdetails)
    quota_home.store("path", home_path + "/Alvis")
    quota_home.store("title", "Home Directory")

    # Cephyr nobackup
    cephyr_nobackup_dirs = get_group_owned_subdirs(user, "/cephyr/NOBACKUP/groups")
    quota_home.store("debug", cephyr_nobackup_dirs)
    res_list.append(quota_home)
    cephyr_nobackup_dirs.each do |dir|
      cephdetails, err = ceph_quota(dir)
      if cephdetails.empty?
        next
      end
      quota = uncephify(cephdetails)
      quota.store("path", dir)
      quota.store("title", dir)
      res_list.append(quota)
    end

    # Mimer nobackup
    weka, error = weka_quota(user)
    weka.each do | wq |
      wq.store("debug", "")
      res_list.append(wq)
    end
    return res_list
  end
end

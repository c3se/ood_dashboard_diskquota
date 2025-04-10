require "open3"
require "etc"
require "json"
require "uri"
require "openssl"
require "net/http"
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
      "usage_bytes" => wekadetail["total_bytes"].to_s,
      "limit_bytes" => wekadetail["hard_limit_bytes"].to_s
    }
  end

  def weka_quota(path)
    weka_url = "https://10.43.40.201:14000/api/v2"
    weka_api_token_file = "/mimer/NOBACKUP/groups/.quota.key"
    weka_api_token = JSON.parse(File.read(weka_api_token_file))
    weka_fs_uuid = 'b3714662-79c0-a799-2738-f292e25c4521'

    # Get quota from Weka API
    inode_id = File.lstat(path).ino
    url = "#{weka_url}/filesystems/#{weka_fs_uuid}/quota/#{inode_id}"
    uri = URI(url)
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{weka_api_token}"
    request['Accept'] = 'application/json'

    # Perform HTTP request
    response = Net::HTTP.start(uri.hostname, uri.port, verify_mode: OpenSSL::SSL::VERIFY_NONE) do |http|
      http.request(request)
    end

    # Handle response
    res, error = {}, nil
    if response.code.to_i == 200
      data = JSON.parse(response.body)['data']
      res.store('total_bytes', data['used_bytes'])
      res.store('hard_limit_bytes', data['hard_limit_bytes'])
    elsif JSON.parse(response.body)['message'] != 'Directory has no quota'
      raise "Error: #{response.body}"
    end
    [res, error]
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
      if dir.directory? and group_gids.include?(dir.gid)
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
    mimer_nobackup_dirs = get_group_owned_subdirs(user, "/mimer/NOBACKUP/groups")
    mimer_nobackup_dirs.each do |dir|
      wekadetails, err = weka_quota(dir)
      if wekadetails.empty?
        next
      end
      quota = unwekaify(wekadetails)
      quota.store("path", dir)
      quota.store("title", dir)
      res_list.append(quota)
    end

    return res_list
  end
end


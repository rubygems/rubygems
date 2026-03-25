require "win32/process"
require "rbconfig"

testuser = "testuser"
testpassword = "Password123+"

# Remove a previous test user if present
# See https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/net-user
system("net user #{testuser} /del 2>NUL")
# Create a new non-admin user
system("net user #{testuser} \"#{testpassword}\" /add")

pinfo = nil
IO.pipe do |stdout_read, stdout_write|
  cmd = ARGV.join(" ")
  env = {
    "TMP" => "#{Dir.pwd}/tmp",
    "TEMP" => "#{Dir.pwd}/tmp"
  }
  pinfo = Process.create command_line: cmd,
    with_logon: testuser,
    password: testpassword,
    cwd: Dir.pwd,
    environment: ENV.to_h.merge(env).map{|k,v| "#{k}=#{v}" },
    startup_info: { stdout: stdout_write, stderr: stdout_write }

  stdout_write.close
  stdout_read.each_line do |line|
    puts(line)
  end
end

# Wait for process to terminate
sleep 1 while !(ecode=Process.get_exitcode(pinfo.process_id))

exit ecode

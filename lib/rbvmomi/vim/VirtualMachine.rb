module RbVmomi::Helper
  class GuestProcess
    def initialize vm, pid
      @vm = vm
      @pid = pid
    end
    
    def processInfo
      @vm._guestProcessManager.ListProcessesInGuest(
        :vm => @vm, 
        :auth => @vm._guestAuth, 
        :pids => [@pid]).first
    end
    
    def done?
      processInfo.exitCode != nil
    end
    
    def wait_for_completion timeout = nil
      startTime = Time.now
      while !done?
        if timeout && (Time.now - startTime) > timeout
          raise "Process #{@pid} on #{@vm.name} did not complete in time"
        end
        sleep 2
      end
    end
  end
end

class RbVmomi::VIM::VirtualMachine
  # Retrieve the MAC addresses for all virtual NICs.
  # @return [Hash] Keyed by device label.
  def macs
    Hash[self.config.hardware.device.grep(RbVmomi::VIM::VirtualEthernetCard).map { |x| [x.deviceInfo.label, x.macAddress] }]
  end
  
  # Retrieve all virtual disk devices.
  # @return [Array] Array of virtual disk devices.
  def disks
    self.config.hardware.device.grep(RbVmomi::VIM::VirtualDisk)
  end
  
  def _guestProcessManager
    @guestProcessManager ||= _connection.serviceContent.guestOperationsManager.processManager
  end

  def _guestFileManager
    @guestFileManager ||= _connection.serviceContent.guestOperationsManager.fileManager
  end
  
  def setGuestAuth username, password
    @guestAuth = VIM::NamePasswordAuthentication(
      :username => username, 
      :password => password, 
      :interactiveSession => true)
    true
  end
  
  def _guestAuth
    @guestAuth
  end
  
  def runGuestProcess cmd, args = nil, env = {}
    fail "need to call setGuestAuth first" if !@guestAuth
    pid = _guestProcessManager.StartProgramInGuest(
      :vm => self, 
      :auth => @guestAuth, 
      :spec => {
        :programPath => cmd, 
        :arguments => args 
      }
    )
    RbVmomi::Helper::GuestProcess.new self, pid
  end
  
  def listGuestFiles path, matchPattern = nil
    _guestFileManager.ListFilesInGuest(
      :vm => self, 
      :auth => @guestAuth, 
      :filePath => path, 
      :matchPattern => matchPattern)
  end
  
  def _downloadFile uri, filename
    uri = URI.parse(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    if uri.scheme == 'https'
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end
    http.request_get(uri.path + '?' + uri.query) do |res|
      File.open filename, 'w' do |io|
        res.read_body do |data|
          io.write data
          $stdout.write '.'
          $stdout.flush
        end
      end
      puts
    end
  end
  
  def downloadGuestFile guestFilename, localFilename
    x = _guestFileManager.InitiateFileTransferFromGuest(
      :vm => self, 
      :auth => @guestAuth, 
      :guestFilePath => guestFilename)
    _downloadFile x.url, localFilename
    x.size
  end
end

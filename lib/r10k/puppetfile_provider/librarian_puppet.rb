require 'r10k/puppetfile_provider/driver'


module R10K
module PuppetfileProvider
  module LibrarianVersion
    def version
      defined_version
    end
  end

  class LibrarianPuppet < Driver

    def initialize(basedir, moduledir = nil, puppetfile_path = nil)
      load_librarian_gem
      super
    end

    def load_librarian_gem
      begin
        require 'puppet' # librarian bails out completely (with an `exit 1`) if Puppet cannot be loaded so try it here
        require 'librarian/action/install'
        require 'librarian/puppet/extension' # patches Install to be non-destructive
      rescue LoadError
        raise 'Install `librarian-puppet` and `puppet` Gems to use Librarian-puppet integration'
      end
    end

    def sync_modules
      sync
    end

    def sync_module(mod)
      raise "Librarian Puppet does not support individual module deployment"
    end

    def sync
      execute_if_puppetfile_exists do
        Librarian::Action::Install.new(environment, {}).run
      end
    end

    def purge
      if environment.config_db.local['destructive'] == 'true'
        sync
      else
        while_destructive do
          sync
        end
      end

    end

    def modules
      if puppetfile_exists?
        environment.lock.manifests.collect do |mod|
           mod.extend(LibrarianVersion)
        end
      else
        []
      end
    end

    private

    def environment
      @environment ||= Librarian::Puppet::Environment.new(:pwd => @basedir)
    end

    def while_destructive
      environment.config_db.local['destructive'] = 'true'
      yield if block_given?
    ensure
        environment.config_db.local['destructive'] = 'false'
    end

    # TODO: remove this same logic from R10K::Puppetfile and implement on the base class
    def execute_if_puppetfile_exists
      if puppetfile_exists?
        yield if block_given?
      else
        logger.debug "Puppetfile in #{@basedir} missing or unreadable"
      end
    end


  end
end
end

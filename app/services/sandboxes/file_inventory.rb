module Sandboxes
  class FileInventory
    DEFAULT_LIMIT = 40

    def self.call(sandbox_session, limit: DEFAULT_LIMIT)
      new(sandbox_session, limit: limit).call
    end

    def initialize(sandbox_session, limit:)
      @sandbox_session = sandbox_session
      @limit = limit
    end

    def call
      return [] unless sandbox_root.directory? && inside_storage_root?

      sandbox_root
        .children
        .flat_map { |path| inventory(path) }
        .sort_by { |entry| [ entry.fetch(:type) == "directory" ? 0 : 1, entry.fetch(:path) ] }
        .first(@limit)
    rescue Errno::ENOENT, Errno::EACCES
      []
    end

    private

    def sandbox_root
      @sandbox_root ||= Pathname.new(@sandbox_session.worktree_path.to_s).cleanpath
    end

    def storage_root
      @storage_root ||= Rails.root.join("storage", "runs").cleanpath
    end

    def inside_storage_root?
      sandbox_root.to_s.start_with?("#{storage_root}/")
    end

    def inventory(path)
      return [] if path.basename.to_s == ".git"

      if path.directory?
        directory_entry = entry_for(path, "directory")
        [ directory_entry ] + path.children.flat_map { |child| inventory(child) }
      elsif path.file?
        [ entry_for(path, "file") ]
      else
        []
      end
    end

    def entry_for(path, type)
      stat = path.stat
      {
        path: path.relative_path_from(sandbox_root).to_s,
        type: type,
        byte_size: type == "file" ? stat.size : nil,
        modified_at: stat.mtime
      }
    end
  end
end

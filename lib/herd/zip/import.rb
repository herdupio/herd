module Herd
  module Zip
    class Import < Base
      attr_accessor :zip_path
      attr_accessor :accept_extensions

      def accept_extensions
        @accept_extensions ||= %w(.jpg .gif .png .mp4 .mov .webm)
      end
      def self.import(zip_path)
        new(zip_path).import
      end

      def initialize(zip_path)
        @zip_path = zip_path
        @accept_extensions
      end

      def import(path=nil)
        @zip_path = path if path
        zip_data = open zip_path

        assets=[]

        ::Zip::File.open(zip_data) do |zip|
          zip.each do |entry|
            next if entry.name =~ /\.DS_Store|__MACOSX|(^|\/)\._/
            next unless accept_extensions.include? File.extname(entry.name).downcase

            parts = entry.name.split '/'
            begin
              parts.first.classify.constantize
            rescue NameError
              parts.shift
            end

            asset_file = parts.pop
            assetable_slug = parts.pop

            begin
              klass = class_from_path parts.join '/'
              object = klass.friendly.find assetable_slug
            rescue Exception => e
              puts "no item found #{assetable_slug} #{e} #{parts}"
              next
            end

            assetable_path = Rails.root.join 'tmp','import',*parts,assetable_slug
            asset_path = File.join assetable_path,asset_file

            FileUtils.mkdir_p assetable_path
            FileUtils.rm asset_path if File.exist? asset_path

            entry.extract asset_path

            if found = object.assets.master.find_by(file_name: File.basename(asset_path))
              puts "linked this file is #{asset_path} \n exist: #{found}"
            else
              assets << object.assets.create(file: asset_path.to_s)
            end

          end
        end

        FileUtils.rm_rf Rails.root.join('tmp','import')

        assets
      end

    end
  end
end
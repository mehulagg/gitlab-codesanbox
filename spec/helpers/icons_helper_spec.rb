# frozen_string_literal: true

require 'spec_helper'

RSpec.describe IconsHelper do
  let(:icons_path) { ActionController::Base.helpers.image_path("icons.svg") }

  describe 'icon' do
    it 'returns aria-hidden by default' do
      star = icon('star')

      expect(star['aria-hidden']).to eq 'aria-hidden'
    end

    it 'does not return aria-hidden if aria-label is set' do
      up = icon('up', 'aria-label' => 'up')

      expect(up['aria-hidden']).to be_nil
      expect(up['aria-label']).to eq 'aria-label'
    end
  end

  describe 'sprite_icon_path' do
    it 'returns relative path' do
      expect(sprite_icon_path).to eq(icons_path)
    end

    it 'only calls image_path once when called multiple times' do
      expect(ActionController::Base.helpers).to receive(:image_path).once.and_call_original

      2.times { sprite_icon_path }
    end

    context 'when an asset_host is set in the config it will return an absolute local URL' do
      let(:asset_host) { 'http://assets' }

      before do
        allow(ActionController::Base).to receive(:asset_host).and_return(asset_host)
      end

      it 'returns an absolute URL on that asset host' do
        expect(sprite_icon_path)
          .to eq ActionController::Base.helpers.image_path("icons.svg", host: Gitlab.config.gitlab.url)
      end
    end
  end

  describe 'sprite_icon' do
    icon_name = 'clock'

    it 'returns svg icon html with DEFAULT_ICON_SIZE' do
      expect(sprite_icon(icon_name).to_s)
        .to eq "<svg class=\"s#{IconsHelper::DEFAULT_ICON_SIZE}\" data-testid=\"#{icon_name}-icon\"><use xlink:href=\"#{icons_path}##{icon_name}\"></use></svg>"
    end

    it 'returns svg icon html without size class' do
      expect(sprite_icon(icon_name, size: nil).to_s)
        .to eq "<svg data-testid=\"#{icon_name}-icon\"><use xlink:href=\"#{icons_path}##{icon_name}\"></use></svg>"
    end

    it 'returns svg icon html + size classes' do
      expect(sprite_icon(icon_name, size: 72).to_s)
        .to eq "<svg class=\"s72\" data-testid=\"#{icon_name}-icon\"><use xlink:href=\"#{icons_path}##{icon_name}\"></use></svg>"
    end

    it 'returns svg icon html + size classes + additional class' do
      expect(sprite_icon(icon_name, size: 72, css_class: 'icon-danger').to_s)
        .to eq "<svg class=\"s72 icon-danger\" data-testid=\"#{icon_name}-icon\"><use xlink:href=\"#{icons_path}##{icon_name}\"></use></svg>"
    end

    describe 'non existing icon' do
      non_existing = 'non_existing_icon_sprite'

      it 'raises in development mode' do
        stub_rails_env('development')

        expect { sprite_icon(non_existing) }.to raise_error(ArgumentError, /is not a known icon/)
      end

      it 'raises in test mode' do
        stub_rails_env('test')

        expect { sprite_icon(non_existing) }.to raise_error(ArgumentError, /is not a known icon/)
      end

      it 'does not raise in production mode' do
        stub_rails_env('production')

        expect(File).not_to receive(:read)

        expect { sprite_icon(non_existing) }.not_to raise_error
      end
    end
  end

  describe 'audit icon' do
    it 'returns right icon name for standard auth' do
      icon_name = 'standard'
      expect(audit_icon(icon_name).to_s)
          .to eq '<i class="fa fa-key"></i>'
    end

    it 'returns right icon name for two-factor auth' do
      icon_name = 'two-factor'
      expect(audit_icon(icon_name).to_s)
          .to eq '<i class="fa fa-key"></i>'
    end

    it 'returns right icon name for google_oauth2 auth' do
      icon_name = 'google_oauth2'
      expect(audit_icon(icon_name).to_s)
          .to eq '<i class="fa fa-google"></i>'
    end
  end

  describe 'file_type_icon_class' do
    it 'returns folder class' do
      expect(file_type_icon_class('folder', 0, 'folder_name')).to eq 'folder'
    end

    it 'returns share class' do
      expect(file_type_icon_class('file', '120000', 'link')).to eq 'share'
    end

    it 'returns file-pdf-o class with .pdf' do
      expect(file_type_icon_class('file', 0, 'filename.pdf')).to eq 'file-pdf-o'
    end

    it 'returns file-image-o class with .jpg' do
      expect(file_type_icon_class('file', 0, 'filename.jpg')).to eq 'file-image-o'
    end

    it 'returns file-image-o class with .JPG' do
      expect(file_type_icon_class('file', 0, 'filename.JPG')).to eq 'file-image-o'
    end

    it 'returns file-image-o class with .png' do
      expect(file_type_icon_class('file', 0, 'filename.png')).to eq 'file-image-o'
    end

    it 'returns file-image-o class with .apng' do
      expect(file_type_icon_class('file', 0, 'filename.apng')).to eq 'file-image-o'
    end

    it 'returns file-image-o class with .webp' do
      expect(file_type_icon_class('file', 0, 'filename.webp')).to eq 'file-image-o'
    end

    it 'returns file-archive-o class with .tar' do
      expect(file_type_icon_class('file', 0, 'filename.tar')).to eq 'file-archive-o'
    end

    it 'returns file-archive-o class with .TAR' do
      expect(file_type_icon_class('file', 0, 'filename.TAR')).to eq 'file-archive-o'
    end

    it 'returns file-archive-o class with .tar.gz' do
      expect(file_type_icon_class('file', 0, 'filename.tar.gz')).to eq 'file-archive-o'
    end

    it 'returns file-audio-o class with .mp3' do
      expect(file_type_icon_class('file', 0, 'filename.mp3')).to eq 'file-audio-o'
    end

    it 'returns file-audio-o class with .MP3' do
      expect(file_type_icon_class('file', 0, 'filename.MP3')).to eq 'file-audio-o'
    end

    it 'returns file-audio-o class with .m4a' do
      expect(file_type_icon_class('file', 0, 'filename.m4a')).to eq 'file-audio-o'
    end

    it 'returns file-audio-o class with .wav' do
      expect(file_type_icon_class('file', 0, 'filename.wav')).to eq 'file-audio-o'
    end

    it 'returns file-video-o class with .avi' do
      expect(file_type_icon_class('file', 0, 'filename.avi')).to eq 'file-video-o'
    end

    it 'returns file-video-o class with .AVI' do
      expect(file_type_icon_class('file', 0, 'filename.AVI')).to eq 'file-video-o'
    end

    it 'returns file-video-o class with .mp4' do
      expect(file_type_icon_class('file', 0, 'filename.mp4')).to eq 'file-video-o'
    end

    it 'returns file-word-o class with .odt' do
      expect(file_type_icon_class('file', 0, 'filename.odt')).to eq 'file-word-o'
    end

    it 'returns file-word-o class with .doc' do
      expect(file_type_icon_class('file', 0, 'filename.doc')).to eq 'file-word-o'
    end

    it 'returns file-word-o class with .DOC' do
      expect(file_type_icon_class('file', 0, 'filename.DOC')).to eq 'file-word-o'
    end

    it 'returns file-word-o class with .docx' do
      expect(file_type_icon_class('file', 0, 'filename.docx')).to eq 'file-word-o'
    end

    it 'returns file-excel-o class with .xls' do
      expect(file_type_icon_class('file', 0, 'filename.xls')).to eq 'file-excel-o'
    end

    it 'returns file-excel-o class with .XLS' do
      expect(file_type_icon_class('file', 0, 'filename.XLS')).to eq 'file-excel-o'
    end

    it 'returns file-excel-o class with .xlsx' do
      expect(file_type_icon_class('file', 0, 'filename.xlsx')).to eq 'file-excel-o'
    end

    it 'returns file-excel-o class with .odp' do
      expect(file_type_icon_class('file', 0, 'filename.odp')).to eq 'file-powerpoint-o'
    end

    it 'returns file-excel-o class with .ppt' do
      expect(file_type_icon_class('file', 0, 'filename.ppt')).to eq 'file-powerpoint-o'
    end

    it 'returns file-excel-o class with .PPT' do
      expect(file_type_icon_class('file', 0, 'filename.PPT')).to eq 'file-powerpoint-o'
    end

    it 'returns file-excel-o class with .pptx' do
      expect(file_type_icon_class('file', 0, 'filename.pptx')).to eq 'file-powerpoint-o'
    end

    it 'returns file-text-o class with .unknow' do
      expect(file_type_icon_class('file', 0, 'filename.unknow')).to eq 'file-text-o'
    end

    it 'returns file-text-o class with no extension' do
      expect(file_type_icon_class('file', 0, 'CHANGELOG')).to eq 'file-text-o'
    end
  end

  describe '#external_snippet_icon' do
    it 'returns external snippet icon' do
      expect(external_snippet_icon('download').to_s)
        .to eq("<span class=\"gl-snippet-icon gl-snippet-icon-download\"></span>")
    end
  end

  describe 'loading_icon' do
    it 'returns span with gl-spinner class and default configuration' do
      expect(loading_icon.to_s)
        .to eq '<span class="gl-spinner gl-spinner-orange gl-spinner-sm" aria-label="Loading"></span>'
    end

    context 'when css_class is provided' do
      it 'appends css_class to gl-spinner element' do
        expect(loading_icon(css_class: 'gl-mr-2').to_s)
          .to eq '<span class="gl-spinner gl-spinner-orange gl-spinner-sm gl-mr-2" aria-label="Loading"></span>'
      end
    end

    context 'when container is true' do
      it 'creates a container that has the gl-spinner-container class selector' do
        expect(loading_icon(container: true).to_s)
        .to eq '<div class="gl-spinner-container"><span class="gl-spinner gl-spinner-orange gl-spinner-sm" aria-label="Loading"></span></div>'
      end
    end
  end
end

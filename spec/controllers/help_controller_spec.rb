# frozen_string_literal: true

require 'spec_helper'

RSpec.describe HelpController do
  let(:user) { create(:user) }

  before do
    sign_in(user)
  end

  describe 'GET #index' do
    context 'with absolute url' do
      it 'keeps the URL absolute' do
        stub_readme("[API](/api/README.md)")

        get :index

        expect(assigns[:help_index]).to eq '[API](/api/README.md)'
      end
    end

    context 'with relative url' do
      it 'prefixes it with /help/' do
        stub_readme("[API](api/README.md)")

        get :index

        expect(assigns[:help_index]).to eq '[API](/help/api/README.md)'
      end
    end

    context 'when url is an external link' do
      it 'does not change it' do
        stub_readme("[external](https://some.external.link)")

        get :index

        expect(assigns[:help_index]).to eq '[external](https://some.external.link)'
      end
    end

    context 'when relative url with external on same line' do
      it 'prefix it with /help/' do
        stub_readme("[API](api/README.md) [external](https://some.external.link)")

        get :index

        expect(assigns[:help_index]).to eq '[API](/help/api/README.md) [external](https://some.external.link)'
      end
    end

    context 'when relative url with http:// in query' do
      it 'prefix it with /help/' do
        stub_readme("[API](api/README.md?go=https://example.com/)")

        get :index

        expect(assigns[:help_index]).to eq '[API](/help/api/README.md?go=https://example.com/)'
      end
    end

    context 'when mailto URL' do
      it 'do not change it' do
        stub_readme("[report bug](mailto:bugs@example.com)")

        get :index

        expect(assigns[:help_index]).to eq '[report bug](mailto:bugs@example.com)'
      end
    end

    context 'when protocol-relative link' do
      it 'do not change it' do
        stub_readme("[protocol-relative](//example.com)")

        get :index

        expect(assigns[:help_index]).to eq '[protocol-relative](//example.com)'
      end
    end

    context 'restricted visibility set to public' do
      before do
        sign_out(user)

        stub_application_setting(restricted_visibility_levels: [Gitlab::VisibilityLevel::PUBLIC])
      end

      it 'redirects to sign_in path' do
        get :index

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe 'GET #show' do
    context 'for Markdown formats' do
      context 'when requested file exists' do
        before do
          expect(File).to receive(:read).and_return(fixture_file('blockquote_fence_after.md'))
          get :show, params: { path: 'ssh/README' }, format: :md
        end

        it 'assigns to @markdown' do
          expect(assigns[:markdown]).not_to be_empty
        end

        it 'renders HTML' do
          expect(response).to render_template('show.html.haml')
          expect(response.media_type).to eq 'text/html'
        end
      end

      context 'when requested file is missing' do
        it 'renders not found' do
          get :show, params: { path: 'foo/bar' }, format: :md
          expect(response).to be_not_found
        end
      end
    end

    context 'for image formats' do
      context 'when requested file exists' do
        it 'renders the raw file' do
          get :show,
              params: {
                path: 'user/img/markdown_logo'
              },
              format: :png
          expect(response).to be_successful
          expect(response.media_type).to eq 'image/png'
          expect(response.headers['Content-Disposition']).to match(/^inline;/)
        end
      end

      context 'when requested file is missing' do
        it 'renders not found' do
          get :show,
              params: {
                path: 'foo/bar'
              },
              format: :png
          expect(response).to be_not_found
        end
      end
    end

    context 'for other formats' do
      it 'always renders not found' do
        get :show,
            params: {
              path: 'ssh/README'
            },
            format: :foo
        expect(response).to be_not_found
      end
    end
  end

  def stub_readme(content)
    expect(File).to receive(:read).and_return(content)
  end
end

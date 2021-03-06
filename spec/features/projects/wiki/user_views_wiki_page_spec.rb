# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User views a wiki page' do
  include WikiHelpers

  let(:user) { create(:user) }
  let(:project) { create(:project, :wiki_repo, namespace: user.namespace) }
  let(:path) { 'image.png' }
  let(:wiki) { project.wiki }
  let(:wiki_page) do
    create(:wiki_page,
           wiki: wiki,
           title: 'home', content: "Look at this [image](#{path})\n\n ![alt text](#{path})")
  end

  before do
    project.add_maintainer(user)
    sign_in(user)
  end

  context 'when wiki is empty', :js do
    before do
      visit project_wikis_path(project)

      wait_for_svg_to_be_loaded

      click_link "Create your first page"

      fill_in(:wiki_title, with: 'one/two/three-test')

      page.within('.wiki-form') do
        fill_in(:wiki_content, with: 'wiki content')
        click_on('Create page')
      end

      expect(page).to have_content('Wiki was successfully updated.')
    end

    it 'shows the history of a page that has a path' do
      expect(current_path).to include('one/two/three-test')

      first(:link, text: 'three').click
      click_on('Page history')

      expect(current_path).to include('one/two/three-test')

      page.within(:css, '.nav-text') do
        expect(page).to have_content('History')
      end
    end

    it 'shows an old version of a page' do
      expect(current_path).to include('one/two/three-test')
      expect(find('.wiki-pages')).to have_content('three')

      first(:link, text: 'three').click

      expect(find('.nav-text')).to have_content('three')

      click_on('Edit')

      expect(current_path).to include('one/two/three-test')
      expect(page).to have_content('Edit Page')

      fill_in('Content', with: 'Updated Wiki Content')
      click_on('Save changes')

      expect(page).to have_content('Wiki was successfully updated.')

      click_on('Page history')

      within('.nav-text') do
        expect(page).to have_content('History')
      end

      within('.wiki-history') do
        expect(page).to have_css('a[href*="?version_id"]', count: 4)
      end
    end
  end

  context 'when a page does not have history' do
    before do
      visit(project_wiki_path(project, wiki_page))
    end

    it 'shows all the pages' do
      expect(page).to have_content(user.name)
      expect(find('.wiki-pages')).to have_content(wiki_page.title.capitalize)
    end

    context 'shows a file stored in a page' do
      let(:path) { upload_file_to_wiki(project, user, 'dk.png') }

      it do
        expect(page).to have_xpath("//img[@data-src='#{wiki.wiki_base_path}/#{path}']")
        expect(page).to have_link('image', href: "#{wiki.wiki_base_path}/#{path}")

        click_on('image')

        expect(current_path).to match("wikis/#{path}")
        expect(page).not_to have_xpath('/html') # Page should render the image which means there is no html involved
      end
    end

    it 'shows the creation page if file does not exist' do
      expect(page).to have_link('image', href: "#{wiki.wiki_base_path}/#{path}")

      click_on('image')

      expect(current_path).to match("wikis/#{path}")
      expect(page).to have_content('Create New Page')
    end
  end

  context 'when a page has history' do
    before do
      wiki_page.update(message: 'updated home', content: 'updated [some link](other-page)') # rubocop:disable Rails/SaveBang
    end

    it 'shows the page history' do
      visit(project_wiki_path(project, wiki_page))

      expect(page).to have_selector('a.btn', text: 'Edit')

      click_on('Page history')

      expect(page).to have_content(user.name)
      expect(page).to have_content("#{user.username} created page: home")
      expect(page).to have_content('updated home')
    end

    it 'does not show the "Edit" button' do
      visit(project_wiki_path(project, wiki_page, version_id: wiki_page.versions.last.id))

      expect(page).not_to have_selector('a.btn', text: 'Edit')
    end

    context 'show the diff' do
      def expect_diff_links(commit)
        diff_path = wiki_page_path(wiki, wiki_page, version_id: commit, action: :diff)

        expect(page).to have_link('Hide whitespace changes', href: "#{diff_path}&w=1")
        expect(page).to have_link('Inline', href: "#{diff_path}&view=inline")
        expect(page).to have_link('Side-by-side', href: "#{diff_path}&view=parallel")
        expect(page).to have_link("View page @ #{commit.short_id}", href: wiki_page_path(wiki, wiki_page, version_id: commit))
        expect(page).to have_css('.diff-file[data-blob-diff-path="%s"]' % diff_path)
      end

      it 'links to the correct diffs' do
        visit project_wiki_history_path(project, wiki_page)

        commit1 = wiki.commit('HEAD^')
        commit2 = wiki.commit

        expect(page).to have_link('created page: home', href: wiki_page_path(wiki, wiki_page, version_id: commit1, action: :diff))
        expect(page).to have_link('updated home', href: wiki_page_path(wiki, wiki_page, version_id: commit2, action: :diff))
      end

      it 'between the current and the previous version of a page' do
        commit = wiki.commit
        visit wiki_page_path(wiki, wiki_page, version_id: commit, action: :diff)

        expect(page).to have_content('by John Doe')
        expect(page).to have_content('updated home')
        expect(page).to have_content('Showing 1 changed file with 1 addition and 3 deletions')
        expect(page).to have_content('some link')

        expect_diff_links(commit)
      end

      it 'between two old versions of a page' do
        wiki_page.update(message: 'latest home change', content: 'updated [another link](other-page)') # rubocop:disable Rails/SaveBang:
        commit = wiki.commit('HEAD^')
        visit wiki_page_path(wiki, wiki_page, version_id: commit, action: :diff)

        expect(page).to have_content('by John Doe')
        expect(page).to have_content('updated home')
        expect(page).to have_content('Showing 1 changed file with 1 addition and 3 deletions')
        expect(page).to have_content('some link')
        expect(page).not_to have_content('latest home change')
        expect(page).not_to have_content('another link')

        expect_diff_links(commit)
      end

      it 'for the oldest version of a page' do
        commit = wiki.commit('HEAD^')
        visit wiki_page_path(wiki, wiki_page, version_id: commit, action: :diff)

        expect(page).to have_content('by John Doe')
        expect(page).to have_content('created page: home')
        expect(page).to have_content('Showing 1 changed file with 4 additions and 0 deletions')
        expect(page).to have_content('Look at this')

        expect_diff_links(commit)
      end
    end
  end

  context 'when a page has special characters in its title' do
    let(:title) { '<foo> !@#$%^&*()[]{}=_+\'"\\|<>? <bar>' }

    before do
      wiki_page.update(title: title ) # rubocop:disable Rails/SaveBang
    end

    it 'preserves the special characters' do
      visit(project_wiki_path(project, wiki_page))

      expect(page).to have_css('.wiki-page-title', text: title)
      expect(page).to have_css('.wiki-pages li', text: title)
    end
  end

  context 'when a page has XSS in its title or content' do
    let(:title) { '<script>alert("title")<script>' }

    before do
      wiki_page.update(title: title, content: 'foo <script>alert("content")</script> bar') # rubocop:disable Rails/SaveBang
    end

    it 'safely displays the page' do
      visit(project_wiki_path(project, wiki_page))

      expect(page).to have_css('.wiki-page-title', text: title)
      expect(page).to have_content('foo bar')
    end
  end

  context 'when a page has XSS in its message' do
    before do
      wiki_page.update(message: '<script>alert(true)<script>', content: 'XSS update') # rubocop:disable Rails/SaveBang
    end

    it 'safely displays the message' do
      visit(project_wiki_history_path(project, wiki_page))

      expect(page).to have_content('<script>alert(true)<script>')
    end
  end

  context 'when page has invalid content encoding' do
    let(:content) { (+'whatever').force_encoding('ISO-8859-1') }

    before do
      allow(Gitlab::EncodingHelper).to receive(:encode!).and_return(content)

      visit(project_wiki_path(project, wiki_page))
    end

    it 'does not show "Edit" button' do
      expect(page).not_to have_selector('a.btn', text: 'Edit')
    end

    it 'shows error' do
      page.within(:css, '.flash-notice') do
        expect(page).to have_content('The content of this page is not encoded in UTF-8. Edits can only be made via the Git repository.')
      end
    end
  end

  it 'opens a default wiki page', :js do
    visit project_path(project)

    find('.shortcuts-wiki').click

    wait_for_svg_to_be_loaded

    click_link "Create your first page"

    expect(page).to have_content('Create New Page')
  end
end

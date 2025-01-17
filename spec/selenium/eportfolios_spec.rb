require File.expand_path(File.dirname(__FILE__) + '/common')
require File.expand_path(File.dirname(__FILE__) + '/helpers/eportfolios_common')

describe "eportfolios" do
  include_context "in-process server selenium tests"
  include EportfoliosCommon

  before(:each) do
    course_with_student_logged_in
  end

  it "should create an eportfolio", priority: "1", test_id: 220018 do
    create_eportfolio
  end

  it "should create an eportfolio that is public", priority: "2", test_id: 114348 do
    create_eportfolio(true)
  end

  context "eportfolio created with user" do
    before(:each) do
      eportfolio_model({:user => @user, :name => "student content"})
    end

    it "should start the download of ePortfolio contents", priority: "1", test_id: 115980 do
      get "/eportfolios/#{@eportfolio.id}"
      f(".download_eportfolio_link").click
      keep_trying_until { expect(f("#export_progress")).to be_displayed }
    end

    it "should display the eportfolio wizard", priority: "1", test_id: 220019 do
      get "/eportfolios/#{@eportfolio.id}"
      f(".wizard_popup_link").click
      wait_for_animations
      expect(f("#wizard_box")).to be_displayed
    end

    it "should display and hide eportfolio wizard", priority: "2", test_id: 220020 do
      get "/eportfolios/#{@eportfolio.id}"
      f(".wizard_popup_link").click
      wait_for_animations
      keep_trying_until do
        expect(f("#wizard_box")).to be_displayed
        f(".close_wizard_link").click
      end
      wait_for_animations
      expect(f("#wizard_box")).not_to be_displayed
    end

    it "should add a new page", priority: "1", test_id: 115979 do
      page_title = 'I made this page.'

      get "/eportfolios/#{@eportfolio.id}"
      f('.manage_pages_link').click
      wait_for_animations
      f('.add_page_link').click
      wait_for_ajaximations
      replace_content(f('#page_name'), page_title)
      driver.action.send_keys(:return).perform
      wait_for_ajaximations
      fj('.done_editing_button:visible').click
      wait_for_ajaximations
      f('#content').click
      keep_trying_until{
        f("#page_sidebar").click
        f("#page_list").text.include?(page_title)
      }
      get "/eportfolios/#{@eportfolio.id}/category/I_made_this_page"
      wait_for_ajaximations
      expect(f('#section_pages')).to include_text(page_title)
      expect(f('#content h2')).to include_text(page_title)
    end

    it "should add a section" do
      get "/eportfolios/#{@eportfolio.id}"
      f("#section_list_manage .manage_sections_link").click
      f("#section_list_manage .add_section_link").click
      f("#section_list input").send_keys("test section name", :return)
      wait_for_ajax_requests
      expect(fj("#section_list li:last-child .name").text).to eq "test section name"
    end

    it "should edit ePortfolio settings", priority: "2", test_id: 220021 do
      get "/eportfolios/#{@eportfolio.id}"
      f('#section_list_manage .portfolio_settings_link').click
      replace_content f('#edit_eportfolio_form #eportfolio_name'), "new ePortfolio name"
      f('#edit_eportfolio_form #eportfolio_public').click
      submit_form('#edit_eportfolio_form')
      wait_for_ajax_requests
      @eportfolio.reload
      expect(@eportfolio.name).to eq "new ePortfolio name"
    end

    it "should validate time stamp on ePortfolio", priority: "2" do
      # Freezes time to 2 days from today.
      old_time = 2.days.from_now.utc.beginning_of_hour
      Timecop.freeze(old_time) do
        current_time = old_time.strftime('%b %-d at %-l') << old_time.strftime('%p').downcase
        # Saves an entry to initiate an update.
        @eportfolio_entry.save!
        # Checks for correct time.
        get "/dashboard/eportfolios"
        expect(f(".updated_at")).to include_text(current_time)

        # Freezes time to 3 days from previous date.
        new_time = Timecop.freeze(Date.today + 3).utc
        current_time = new_time.strftime('%b %-d at %-l') << new_time.strftime('%p').downcase
        # Saves to initiate an update.
        @eportfolio_entry.save!
        # Checks for correct time, then unfreezes time.
        get "/dashboard/eportfolios"
        expect(f(".updated_at")).to include_text(current_time)
      end
    end

    it "should have a working flickr search dialog" do
      get "/eportfolios/#{@eportfolio.id}"
      f("#page_list a.page_url").click
      keep_trying_until {
        expect(f("#page_list a.page_url")).to be_displayed
      }
      f("#page_sidebar .edit_content_link").click
      keep_trying_until {
        expect(f('.add_content_link.add_rich_content_link')).to be_displayed
      }
      f('.add_content_link.add_rich_content_link').click
      wait_for_tiny(f('textarea.edit_section'))
      keep_trying_until {
        expect(f('.mce-container')).to be_displayed
      }
      f("div[aria-label='Embed Image'] button").click
      keep_trying_until {
        expect(f('a[href="#tabFlickr"]')).to be_displayed
      }
      f('a[href="#tabFlickr"]').click
      keep_trying_until {
        expect(f('form.FindFlickrImageView')).to be_displayed
      }
    end

    it "should not have new section option when adding submission" do
      @assignment = @course.assignments.create!(:title => "hardest assignment ever", :submission_types => "online_url,online_upload")
      @submission = @assignment.submit_homework(@student)
      @submission.submission_type = "online_url"
      @submission.save!
      get "/eportfolios/#{@eportfolio.id}"
      f(".submission").click
      expect(f("#add_submission_form")).to be_displayed
      expect(ff('#category_select option').map(&:text)).not_to include("New Section")
    end


    it "should delete the ePortfolio", priority: "2", test_id: 114350 do
      get "/eportfolios/#{@eportfolio.id}"
      wait_for_ajax_requests
      f(".delete_eportfolio_link").click
      keep_trying_until {
        f("#delete_eportfolio_form").displayed?
      }
      submit_form("#delete_eportfolio_form")
      fj("#wrapper-container .eportfolios").click
      keep_trying_until {
        expect(f("#whats_an_eportfolio .add_eportfolio_link")).to be_displayed
        expect(f("#portfolio_#{@eportfolio.id}")).to be_nil
      }
      expect(Eportfolio.first.workflow_state).to eq 'deleted'
    end

    it "should click on all wizard options and validate the text" do
      get "/eportfolios/#{@eportfolio.id}"
      f('.wizard_popup_link').click
      wait_for_ajaximations
      options_text = {'.information_step' => "ePortfolios are a place to demonstrate your work.",
                      '.portfolio_step' => "Sections are listed along the left side of the window",
                      '.section_step' => "Sections have multiple pages",
                      '.adding_submissions' => "You may have noticed at the bottom of this page is a list of recent submissions",
                      '.edit_step' => "To change the settings for your ePortfolio",
                      '.publish_step' => "Ready to get started?"}
      options_text.each do |option, text|
        f(option).click
        wait_for_animations
        expect(f('.wizard_details .details').text).to include_text text
      end
    end

    it "should be viewable with a shared link" do
      destroy_session
      get "/eportfolios/#{@eportfolio.id}?verifier=#{@eportfolio.uuid}"
      expect(f('#content h2').text).to eq "page"
    end
  end
end

describe "eportfolios file upload" do
  include_context "in-process server selenium tests"

  before (:each) do
    @password = "asdfasdf"
    @student = user_with_pseudonym :active_user => true,
                                   :username => "student@example.com",
                                   :password => @password
    @student.save!
    @course = course :active_course => true
    @course.enroll_student(@student).accept!
    @course.reload
    eportfolio_model({:user => @user, :name => "student content"})
  end

  it "should upload a file" do
    create_session(@student.pseudonym)
    get "/eportfolios/#{@eportfolio.id}"
    filename, fullpath, data = get_file("testfile5.zip")
    expect_new_page_load { f(".icon-arrow-right").click }
    f("#right-side .edit_content_link").click
    wait_for_ajaximations
    driver.execute_script "$('.add_file_link').click()"
    fj(".file_upload:visible").send_keys(fullpath)
    fj(".upload_file_button").click
    wait_for_ajaximations
    submit_form(".form_content")
    wait_for_ajax_requests
    download = f("a.eportfolio_download")
    expect(download).to be_displayed
    expect(download.attribute('href')).not_to be_nil
    #cannot test downloading the file, will check in the future
    #check_file(download)
  end
end

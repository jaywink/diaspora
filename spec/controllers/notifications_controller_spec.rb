#   Copyright (c) 2010-2011, Diaspora Inc.  This file is
#   licensed under the Affero General Public License version 3 or later.  See
#   the COPYRIGHT file.

require 'spec_helper'

describe NotificationsController, :type => :controller do
  before do
    sign_in :user, alice
  end

  describe '#update' do
    it 'marks a notification as read if it gets no other information' do
      note = FactoryGirl.create(:notification)
      expect(Notification).to receive( :where ).and_return( [note] )
      expect(note).to receive( :set_read_state ).with( true )
      get :update, "id" => note.id, :format => :json
    end

    it 'marks a notification as read if it is told to' do
      note = FactoryGirl.create(:notification)
      expect(Notification).to receive( :where ).and_return( [note] )
      expect(note).to receive( :set_read_state ).with( true )
      get :update, "id" => note.id, :set_unread => "false", :format => :json
    end

    it 'marks a notification as unread if it is told to' do
      note = FactoryGirl.create(:notification)
      expect(Notification).to receive( :where ).and_return( [note] )
      expect(note).to receive( :set_read_state ).with( false )
      get :update, "id" => note.id, :set_unread => "true", :format => :json
    end

    it 'only lets you read your own notifications' do
      user2 = bob

      FactoryGirl.create(:notification, :recipient => alice)
      note = FactoryGirl.create(:notification, :recipient => user2)

      get :update, "id" => note.id, :set_unread => "false", :format => :json

      expect(Notification.find(note.id).unread).to eq(true)
    end
  end

  describe '#index' do
    before do
      @post = FactoryGirl.create(:status_message)
      @notification = FactoryGirl.create(:notification, recipient: alice, target: @post)
    end

    it 'succeeds' do
      get :index
      expect(response).to be_success
      expect(assigns[:notifications].count).to eq(1)
    end

    it 'succeeds for notification dropdown' do
      Timecop.travel(6.seconds.ago) do
        @notification.touch
      end
      get :index, :format => :json
      expect(response).to be_success
      note_html = JSON.parse(response.body)[0]["also_commented"]["note_html"]
      note_html = Nokogiri::HTML(note_html)
      timeago_content = note_html.css("time")[0]["data-time-ago"]
      expect(timeago_content).to include(@notification.updated_at.iso8601)
      expect(response.body).to match(/note_html/)
    end

    it 'succeeds on mobile' do
      get :index, :format => :mobile
      expect(response).to be_success
    end

    it 'paginates the notifications' do
      25.times { FactoryGirl.create(:notification, :recipient => alice, :target => @post) }
      get :index
      expect(assigns[:notifications].count).to eq(25)
      get :index, "page" => 2
      expect(assigns[:notifications].count).to eq(1)
    end

    it "supports a limit per_page parameter" do
      2.times { FactoryGirl.create(:notification, :recipient => alice, :target => @post) }
      get :index, "per_page" => 2
      expect(assigns[:notifications].count).to eq(2)
    end

    describe "special case for start sharing notifications" do
      it "should not provide a contacts menu for standard notifications" do
        FactoryGirl.create(:notification, :recipient => alice, :target => @post)
        get :index, "per_page" => 5
        expect(Nokogiri(response.body).css('.aspect_membership')).to be_empty
      end

      it "should provide a contacts menu for start sharing notifications" do
        eve.share_with(alice.person, eve.aspects.first)
        get :index, "per_page" => 5

        expect(Nokogiri(response.body).css('.aspect_membership')).not_to be_empty
      end

      it 'succeeds on mobile' do
        eve.share_with(alice.person, eve.aspects.first)
        get :index, :format => :mobile
        expect(response).to be_success
      end
    end

    describe "filter notifications" do
      it "supports filtering by notification type" do
        FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
        get :index, "type" => "started_sharing"
        expect(assigns[:notifications].count).to eq(1)
      end

      it "supports filtering by read/unread" do
        FactoryGirl.create(:notification, :recipient => alice, :target => @post)
        get :read_all
        FactoryGirl.create(:notification, :recipient => alice, :target => @post)
        get :index, "show" => "unread"
        expect(assigns[:notifications].count).to eq(1)
      end
    end

    context "after deleting a person" do
      before do
        user = FactoryGirl.create(:user_with_aspect)
        user.share_with(alice.person, user.aspects.first)
        user.person.delete
      end

      it "succeeds" do
        get :index
        expect(response).to be_success
      end

      it "succeeds on mobile" do
        get :index, format: :mobile
        expect(response).to be_success
      end
    end
  end

  describe "#read_all" do
    it 'marks all notifications as read' do
      request.env["HTTP_REFERER"] = "I wish I were spelled right"
      FactoryGirl.create(:notification, :recipient => alice, :target => @post)
      FactoryGirl.create(:notification, :recipient => alice, :target => @post)

      expect(Notification.where(:unread => true).count).to eq(2)
      get :read_all
      expect(Notification.where(:unread => true).count).to eq(0)
    end
    it 'marks all notifications in the current filter as read' do
      request.env["HTTP_REFERER"] = "I wish I were spelled right"
      FactoryGirl.create(:notification, :recipient => alice, :target => @post)
      FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
      expect(Notification.where(:unread => true).count).to eq(2)
      get :read_all, "type" => "started_sharing"
      expect(Notification.where(:unread => true).count).to eq(1)
    end
    it "should redirect back in the html version if it has > 0 notifications" do
      FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
      get :read_all, :format => :html, "type" => "liked"
      expect(response).to redirect_to(notifications_path)
    end
    it "should redirect back in the mobile version if it has > 0 notifications" do
      FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
      get :read_all, :format => :mobile, "type" => "liked"
      expect(response).to redirect_to(notifications_path)
    end
    it "should redirect to stream in the html version if it has 0 notifications" do
      FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
      get :read_all, :format => :html, "type" => "started_sharing"
      expect(response).to redirect_to(stream_path)
    end
    it "should redirect back in the mobile version if it has 0 notifications" do
      FactoryGirl.create(:notification, :recipient => alice, :type => "Notifications::StartedSharing")
      get :read_all, :format => :mobile, "type" => "started_sharing"
      expect(response).to redirect_to(stream_path)
    end
    it "should return a dummy value in the json version" do
      FactoryGirl.create(:notification, :recipient => alice, :target => @post)
      get :read_all, :format => :json
      expect(response).not_to be_redirect
    end
  end

  describe "counts" do
    it "succeeds" do
      get :counts
      expect(response).to be_success
    end

    it "returns unread notifications count" do
      post = FactoryGirl.create(:status_message)
      FactoryGirl.create(:notification, recipient: alice, target: post)
      FactoryGirl.create(:notification, recipient: alice, target: post, unread: false)
      get :counts
      expect(response.body).to eq('{"notifications":1}')
    end
  end
end

#
# Copyright (C) 2014 Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper.rb')

describe Lti::LtiOutboundAdapter do
  let(:url) { '/launch/url' }
  let(:account) { Account.new }
  let(:return_url) { '/return/url' }
  let(:user) { User.new }
  let(:resource_type) { :lti_launch_type }
  let(:tool_url) { 'http://www.tool.com/launch/url?firstname=rory' }

  let(:tool) {
    ContextExternalTool.new.tap do |tool|
      tool.stubs(:id).returns('tool_id')
      tool.url = tool_url
    end
  }

  let(:user) {
    User.new.tap do |user|
      user.stubs(:id).returns('user_id')
    end
  }

  let(:context) {
    Course.new.tap do |course|
      course.stubs(:id).returns('course_id')
      course.root_account = account
      course.account = account
    end
  }

  let(:assignment) {
    Assignment.new.tap do |assignment|
      assignment.stubs(:id).returns('assignment_id')
    end
  }

  let(:subject) { adapter }
  let(:adapter) { Lti::LtiOutboundAdapter.new(tool, user, context) }
  let(:lti_consumer_instance) { LtiOutbound::LTIConsumerInstance.new }
  let(:lti_context) {
    LtiOutbound::LTIContext.new.tap do |lti_context|
      lti_context.consumer_instance = lti_consumer_instance
    end
  }
  let(:lti_user) { LtiOutbound::LTIUser.new }
  let(:lti_tool) { LtiOutbound::LTITool.new }
  let(:lti_assignment) { LtiOutbound::LTIAssignment.new }
  let(:controller) do
    request_mock = mock('request')
    request_mock.stubs(:host).returns('/my/url')
    request_mock.stubs(:scheme).returns('https')
    m = mock('controller')
    m.stubs(:request).returns(request_mock)
    m.stubs(:logged_in_user).returns(@user || user)
    m
  end
  let(:variable_expander)do
    Lti::VariableExpander.new(account, context, controller, current_user: user )
  end

  before(:each) do
    Lti::LtiContextCreator.any_instance.stubs(:convert).returns(lti_context)
    Lti::LtiUserCreator.any_instance.stubs(:convert).returns(lti_user)
    Lti::LtiToolCreator.any_instance.stubs(:convert).returns(lti_tool)
    Lti::LtiAssignmentCreator.any_instance.stubs(:convert).returns(lti_assignment)
  end

  describe "#prepare_tool_launch" do
    it "passes the return_url through" do
      LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:return_url] == return_url }

      adapter.prepare_tool_launch(return_url, variable_expander)
    end

    it "generates the outgoing_email_address" do
      HostUrl.stubs(:outgoing_email_address).returns('email@email.com')
      LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:outgoing_email_address] == 'email@email.com' }

      adapter.prepare_tool_launch(return_url, variable_expander)
    end

    context "launch url" do
      it "gets the launch url from the tool" do
        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:url] == tool.url }

        adapter.prepare_tool_launch(return_url, variable_expander)
      end

      it "gets the launch url from the tool settings when resource_type is specified" do
        tool.expects(:extension_setting).with(resource_type, :url).returns('/resource/launch/url')
        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:url] == '/resource/launch/url' }

        adapter.prepare_tool_launch(return_url, variable_expander, resource_type: resource_type)
      end

      it "passes the launch url through when provided" do
        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:url] == url }

        adapter.prepare_tool_launch(return_url, variable_expander, launch_url: url)
      end
    end

    it "accepts selected html" do
      LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:selected_html] == '<div>something</div>' }

      adapter.prepare_tool_launch(return_url, variable_expander, selected_html: '<div>something</div>')
    end

    context "link code" do
      it "generates the link_code when excluded" do
        generated_link_code = 'abc123'
        tool = ContextExternalTool.new
        tool.stubs(:opaque_identifier_for).returns(generated_link_code)
        adapter = Lti::LtiOutboundAdapter.new(tool, user, context)

        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:link_code] == generated_link_code }

        adapter.prepare_tool_launch(return_url, variable_expander)
      end

      it "passes the link_code through when provided" do
        link_code = 'link_code'
        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:link_code] == link_code }

        adapter.prepare_tool_launch(return_url, variable_expander, link_code: link_code)
      end
    end

    context "resource_type" do
      it "passes the resource_type through when provided" do
        LtiOutbound::ToolLaunch.expects(:new).with { |opts| opts[:resource_type] == :lti_launch_type }

        adapter.prepare_tool_launch(return_url, variable_expander, resource_type: resource_type)
      end
    end

    context "lti outbound object creation" do
      it "creates an lti_context" do
        LtiOutbound::ToolLaunch.expects(:new).with { |options| options[:context] == lti_context }

        adapter.prepare_tool_launch(return_url, variable_expander)
      end

      it "creates an lti_user" do
        LtiOutbound::ToolLaunch.expects(:new).with { |options| options[:user] == lti_user }

        adapter.prepare_tool_launch(return_url, variable_expander)
      end

      it "creates an lti_tool" do
        LtiOutbound::ToolLaunch.expects(:new).with { |options| options[:tool] == lti_tool }

        adapter.prepare_tool_launch(return_url, variable_expander)
      end
    end
  end

  context "link_params" do
    let(:link_params) {{ext: {lti_assignment_id: "1234"}}}

    it "passes through the secure_parameters when provided" do
      LtiOutbound::ToolLaunch.expects(:new).with { |options| options[:link_params] == link_params }
      adapter.prepare_tool_launch(return_url, variable_expander, {link_params: link_params})
    end

  end

  describe "#launch_url" do
    it "returns the launch url from the prepared tool launch" do
      tool_launch = mock('tool launch', url: '/launch/url')
      LtiOutbound::ToolLaunch.stubs(:new).returns(tool_launch)
      adapter.prepare_tool_launch(return_url, variable_expander)

      expect(adapter.launch_url).to eq '/launch/url'
    end

    it "raises a not prepared error if the tool launch has not been prepared" do
      expect { adapter.launch_url }.to raise_error(RuntimeError, 'Called launch_url before calling prepare_tool_launch')
    end
  end

  describe "#generate_post_payload" do
    it "calls generate on the tool launch" do
      tool_launch = mock('tool launch')
      tool_launch.expects(generate: {})
      tool_launch.stubs(url: "http://example.com/launch")
      LtiOutbound::ToolLaunch.stubs(:new).returns(tool_launch)
      adapter.prepare_tool_launch(return_url, variable_expander)
      adapter.generate_post_payload
    end

    it "does not copy query params to the post body if oauth_compliant tool setting is enabled" do
      tool.settings = {oauth_compliant: true}
      adapter.prepare_tool_launch(return_url, variable_expander)
      payload = adapter.generate_post_payload
      expect(payload['firstname']).to be_nil
    end

    it "raises a not prepared error if the tool launch has not been prepared" do
      expect { adapter.generate_post_payload }.to raise_error(RuntimeError, 'Called generate_post_payload before calling prepare_tool_launch')
    end
  end

  describe "#generate_post_payload_for_assignment" do
    let(:outcome_service_url) { '/outcome/service' }
    let(:legacy_outcome_service_url) { '/legacy/service' }
    let(:lti_turnitin_outcomes_placement_url) { 'turnitin/outcomes/placement' }
    let(:tool_launch) { stub('tool launch', generate: {}, url: "http://example.com/launch") }

    before(:each) do
      LtiOutbound::ToolLaunch.stubs(:new).returns(tool_launch)
    end

    it "creates an lti_assignment" do
      adapter.prepare_tool_launch(return_url, variable_expander)

      tool_launch.expects(:for_assignment!).with(lti_assignment, outcome_service_url, legacy_outcome_service_url, lti_turnitin_outcomes_placement_url)

      adapter.generate_post_payload_for_assignment(assignment, outcome_service_url, legacy_outcome_service_url, lti_turnitin_outcomes_placement_url)
    end

    it "generates the correct source_id for the assignment" do
      generated_sha = 'generated_sha'
      Canvas::Security.stubs(:hmac_sha1).returns(generated_sha)
      source_id = "tool_id-course_id-assignment_id-user_id-#{generated_sha}"
      tool_launch.stubs(:for_assignment!)
      assignment_creator = mock
      assignment_creator.stubs(:convert).returns(tool_launch)
      adapter.prepare_tool_launch(return_url, variable_expander)

      Lti::LtiAssignmentCreator.expects(:new).with(assignment, source_id).returns(assignment_creator)

      adapter.generate_post_payload_for_assignment(assignment, outcome_service_url, legacy_outcome_service_url, lti_turnitin_outcomes_placement_url)
    end

    it "raises a not prepared error if the tool launch has not been prepared" do
      expect {
        adapter.generate_post_payload_for_assignment(assignment, outcome_service_url, legacy_outcome_service_url, lti_turnitin_outcomes_placement_url)
      }.to raise_error(RuntimeError, 'Called generate_post_payload_for_assignment before calling prepare_tool_launch')
    end

  end

  describe "#generate_post_payload_for_homework_submission" do
    it "creates an lti_assignment" do
      tool_launch = mock('tool launch', generate: {}, url: "http://example.com/launch")
      LtiOutbound::ToolLaunch.stubs(:new).returns(tool_launch)
      adapter.prepare_tool_launch(return_url, variable_expander)

      tool_launch.expects(:for_homework_submission!).with(lti_assignment)

      adapter.generate_post_payload_for_homework_submission(assignment)
    end

    it "raises a not prepared error if the tool launch has not been prepared" do
      expect {
        adapter.generate_post_payload_for_homework_submission(assignment)
      }.to raise_error(RuntimeError, 'Called generate_post_payload_for_homework_submission before calling prepare_tool_launch')
    end
  end

  describe ".consumer_instance_class" do
    around do |example|
      orig_class = Lti::LtiOutboundAdapter.consumer_instance_class
      example.run
      Lti::LtiOutboundAdapter.consumer_instance_class = orig_class
    end

    it "returns the custom instance class if defined" do
      some_class = Class.new
      Lti::LtiOutboundAdapter.consumer_instance_class = some_class

      expect(Lti::LtiOutboundAdapter.consumer_instance_class).to eq some_class
    end

    it "returns the LtiOutbound::LTIConsumerInstance if none defined" do
      Lti::LtiOutboundAdapter.consumer_instance_class = nil
      expect(Lti::LtiOutboundAdapter.consumer_instance_class).to eq LtiOutbound::LTIConsumerInstance
    end
  end
end

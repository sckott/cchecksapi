# frozen_string_literal: true

require 'test/unit'
require_relative '../api'
require_relative '../notifications'

class NotificationsCheck < Test::Unit::TestCase
  def setup
    @rule1 = {
     "package"=>"charlatan",
     "rule_status"=>"note",
     "rule_time"=>nil,
     "rule_platforms"=>nil,
     "rule_regex"=>nil
    }

  end

  def test_notifications_check
    assert_equal(Hash, @rule1.class)
    
    doc = history_query({ name: @rule1["package"] });
    assert_equal(Hash, doc.class)
    
    rl = Rule.new(@rule1, doc);
    assert_equal(Rule, rl.class)
    
    # assert_equal(Array, res.class)
  end
end

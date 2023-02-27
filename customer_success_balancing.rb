require 'minitest/autorun'
require 'timeout'

# ruby-version 3.0.0p0
class CustomerSuccessBalancing
  def initialize(customers_success, customers, away_customer_success)
    @customers_success = customers_success
    @customers = customers
    @away_customer_success = away_customer_success
  end

  def execute
    customers_success.sort_by! { |customer_success| customer_success[:score] }
    customers.sort_by! { |customer| customer[:score] }

    @customers_amount_by_cs = calculate_customers_amount_by_customer_success

    return 0 if customers_amount_by_cs.empty?
    return 0 if customer_success_with_most_customers.size > 1

    customer_success_with_most_customers.last[:customer_success_id]
  end

  private

  attr_reader :away_customer_success, :customers, :customers_success, :customers_amount_by_cs

  # excludes customer success that is absent or does not have enough score to serve customers
  def allocable_customer_success
    customers_success.reject do |customer_success|
      away_customer_success.include?(customer_success[:id]) || customer_success[:score] < customers.first[:score]
    end
  end

  def calculate_customers_amount_by_customer_success
    customers_index = 0

    allocable_customer_success.map do |customer_success|
      customers_amount = 0

      customers[customers_index..].each do |customer|
        break if customer[:score] > customer_success[:score]

        customers_index  += 1
        customers_amount += 1
      end

      { customer_success_id: customer_success[:id], customers_amount: customers_amount }
    end
  end

  def customer_success_with_most_customers
    @customer_success_with_most_customers ||= customers_amount_by_cs.select do |customer_success|
      customer_success[:customers_amount] == max_customers_amount_by_customer_success
    end
  end

  def max_customers_amount_by_customer_success
    customers_amount_by_cs.map do |customer_success|
      customer_success[:customers_amount]
    end.max
  end
end

class CustomerSuccessBalancingTests < Minitest::Test
  def test_scenario_one
    balancer = CustomerSuccessBalancing.new(
      build_scores([60, 20, 95, 75]),
      build_scores([90, 20, 70, 40, 60, 10]),
      [2, 4]
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_two
    balancer = CustomerSuccessBalancing.new(
      build_scores([11, 21, 31, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_three
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array.new(10000, 998)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 998, result
  end

  def test_scenario_four
    balancer = CustomerSuccessBalancing.new(
      build_scores([1, 2, 3, 4, 5, 6]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_five
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 2, 3, 6, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      []
    )
    assert_equal 1, balancer.execute
  end

  def test_scenario_six
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [1, 3, 2]
    )
    assert_equal 0, balancer.execute
  end

  def test_scenario_seven
    balancer = CustomerSuccessBalancing.new(
      build_scores([100, 99, 88, 3, 4, 5]),
      build_scores([10, 10, 10, 20, 20, 30, 30, 30, 20, 60]),
      [4, 5, 6]
    )
    assert_equal 3, balancer.execute
  end

  def test_scenario_eight
    balancer = CustomerSuccessBalancing.new(
      build_scores(Array(1..999)),
      build_scores(Array(1..999999)),
      [999]
    )
    result = Timeout.timeout(1.0) { balancer.execute }
    assert_equal 0, result
  end

  private

  def build_scores(scores)
    scores.map.with_index do |score, index|
      { id: index + 1, score: score }
    end
  end
end

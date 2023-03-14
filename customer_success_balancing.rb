require 'minitest/autorun'
require 'timeout'

# ruby-version 3.0.0p0
class CustomerSuccessBalancing
  DRAW = 0

  def initialize(customers_success, customers, away_customer_success)
    @customers_success = customers_success.sort_by { |cs| cs[:score] }
    @customers = customers.sort_by { |c| c[:score] }
    @away_customer_success = away_customer_success
  end

  def execute
    return DRAW if availables_customers_success.blank?

    calculate_customers_amount_served_per_customer_success
    find_customer_success_id_serving_most_customers
  end

  private

  attr_reader :away_customer_success, :customers, :customers_success, :customers_amount_by_cs

  def availables_customers_success
    @availables_customers_success ||= customers_success.reject do |cs|
      away_customer_success.include?(cs[:id]) || cs[:score] < customers.first[:score]
    end
  end

  def calculate_customers_amount_served_per_customer_success
    customers_index = 0

    @customers_amount_by_cs = availables_customers_success.each_with_object([]) do |cs, customers_amount_by_cs|
      customers_amount = customers[customers_index..].take_while { |c| c[:score] <= cs[:score] }.count

      customers_index += customers_amount

      customers_amount_by_cs << { cs_id: cs[:id], customers_amount: customers_amount }
    end
  end

  def max_customers_amount_by_cs
    @max_customers_amount_by_cs ||= customers_amount_by_cs.map { |cs| cs[:customers_amount] }.max
  end

  def find_customer_success_id_serving_most_customers
    customers_success_serving_most_customers = customers_amount_by_cs.select do |cs|
      cs[:customers_amount] == max_customers_amount_by_cs
    end

    return DRAW if customers_success_serving_most_customers.size > 1

    customers_success_serving_most_customers.last[:cs_id]
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

  # test case with the maximum capacity of customers 🔥
  # without this case the tests run in less than a tenth of a second
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

require File.expand_path(File.dirname(__FILE__) + '/../../spec_helper')

describe Hamster::List do

  [:append, :concat, :cat, :+].each do |method|

    describe "##{method}" do

      describe "on two really big lists" do

        before do
          @a = Hamster.interval(0, 10000)
          @b = Hamster.interval(0, 10000)
        end

        it "doesn't run out of stack space" do
          @a.send(method, @b)
        end

      end

      [
        [[], [], []],
        [["A"], [], ["A"]],
        [[], ["A"], ["A"]],
        [["A", "B"], ["C", "D"], ["A", "B", "C", "D"]],
      ].each do |left_values, right_values, expected|

        describe "on #{left_values.inspect} and #{right_values.inspect}" do

          before do
            @left = Hamster.list(*left_values)
            @right = Hamster.list(*right_values)
            @result = @left.append(@right)
          end

          it "preserves the left" do
            @left.should == Hamster.list(*left_values)
          end

          it "preserves the right" do
            @right.should == Hamster.list(*right_values)
          end

          it "returns #{expected.inspect}" do
            pending {
              @result.should == Hamster.list(*expected)
            }
          end

        end

      end

    end

  end

end
# frozen_string_literal: true

# Released under the MIT License.
# Copyright, 2025, by Duncan Robertson.
# Copyright, 2025, by Samuel Williams.

require "qrcode"

describe QRCode::Encoder::Util do
	it "calculates demerit points for 4 dark ratio" do
		# Test with all white modules (ratio = 0)
		# Expected: (100 * 0 - 50).abs / 5 * 10 = 10 * 10 = 100
		modules = Array.new(4){Array.new(4, false)}
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 100
		
		# Test with all black modules (ratio = 1)
		# Expected: (100 * 1 - 50).abs / 5 * 10 = 50 / 5 * 10 = 10 * 10 = 100
		modules = Array.new(4){Array.new(4, true)}
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 100
		
		# Test with half black, half white modules (ratio = 0.5)
		# Expected: (100 * 0.5 - 50).abs / 5 * 10 = 0 / 5 * 10 = 0
		modules = [
			[true, true, false, false],
			[true, true, false, false],
			[false, false, true, true],
			[false, false, true, true]
		]
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 0
		
		# Test with 25% black modules (ratio = 0.25)
		# Expected: (100 * 0.25 - 50).abs / 5 * 10 = 25 / 5 * 10 = 5 * 10 = 50
		modules = [
			[true, false, false, false],
			[false, true, false, false],
			[false, false, true, false],
			[false, false, false, true]
		]
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 50
		
		# Test with 75% black modules (ratio = 0.75)
		# Expected: (100 * 0.75 - 50).abs / 5 * 10 = 25 / 5 * 10 = 5 * 10 = 50
		modules = [
			[true, true, true, true],
			[true, true, true, false],
			[true, true, false, true],
			[true, false, false, true]
		]
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 50
		
		# Test with different sized modules (3x3)
		# 3 black out of 9 = 1/3 ratio = 0.33...
		# Expected: (100 * (3/9) - 50).abs / 5 * 10 ≈ 16.67 * 10 = 166.7
		modules = [
			[true, false, false],
			[false, true, false],
			[false, false, true]
		]
		expected = ((100 * (3.0 / 9) - 50).abs / 5) * 10
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be_within(0.01).of(expected)
	end
	
	it "handles edge cases for demerit points for 4 dark ratio" do
		# Test with empty modules
		# This shouldn't happen in real QR codes, but let's be safe
		modules = []
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be(:nan?)
		
		# Test with 1x1 module
		# All white
		modules = [[false]]
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 100
		
		# All black
		modules = [[true]]
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be == 100
	end
	
	it "handles formula for demerit points for 4 dark ratio" do
		# Test the formula directly for a specific case
		# For a 5x5 module with 13 dark cells:
		# ratio = 13/25 = 0.52
		# ratio_delta = (100 * 0.52 - 50).abs / 5 = 2/5 = 0.4
		# demerit points = 0.4 * 10 = 4
		modules = [
			[true, true, true, false, false],
			[true, true, true, false, false],
			[true, true, true, false, true],
			[true, true, false, false, false],
			[true, false, false, false, false]
		]
		
		# Count dark modules
		dark_count = modules.flatten.count(true)
		expect(dark_count).to be == 13
		
		# Calculate ratio
		ratio = dark_count.to_f / (5 * 5)
		expect(ratio).to be_within(0.001).of(0.52)
		
		# Calculate ratio_delta
		ratio_delta = (100 * ratio - 50).abs / 5
		expect(ratio_delta).to be_within(0.001).of(0.4)
		
		# Calculate demerit points
		demerit_points = ratio_delta * 10
		expect(demerit_points).to be_within(0.001).of(4)
		
		# Check that our method gives the same result
		expect(QRCode::Encoder::Util.demerit_points_4_dark_ratio(modules)).to be_within(0.001).of(4)
	end
	
	it "calculates demerit points for 1 same color" do
		# 3x3 of one color: only the center has more than 5 equal neighbours (8).
		# Expected: 3 + 8 - 5 = 6
		modules = Array.new(3){Array.new(3, false)}
		expect(QRCode::Encoder::Util.demerit_points_1_same_color(modules)).to be == 6
		
		# 4x4 of one color: the 4 inner modules have 8 equal neighbours, the edges at most 5.
		# Expected: 4 * (3 + 8 - 5) = 24
		modules = Array.new(4){Array.new(4, true)}
		expect(QRCode::Encoder::Util.demerit_points_1_same_color(modules)).to be == 24
		
		# Checkerboard: no module has more than 4 equal neighbours.
		modules = Array.new(5){|row| Array.new(5){|col| (row + col).even?}}
		expect(QRCode::Encoder::Util.demerit_points_1_same_color(modules)).to be == 0
	end
	
	it "calculates demerit points for 1 same color like a plain neighbour count" do
		reference = lambda do |modules|
			count = modules.size
			
			count.times.sum do |row|
				count.times.sum do |col|
					neighbours = [-1, 0, 1].product([-1, 0, 1]) - [[0, 0]]
					same_count = neighbours.count do |r, c|
						(row + r).between?(0, count - 1) && (col + c).between?(0, count - 1) && modules[row + r][col + c] == modules[row][col]
					end
					
					same_count > 5 ? QRCode::Encoder::Util::DEMERIT_POINTS_1 + same_count - 5 : 0
				end
			end
		end
		
		random = Random.new(1)
		[1, 2, 21, 25, 57].each do |size|
			10.times do
				modules = Array.new(size){Array.new(size){random.rand < 0.6}}
				expect(QRCode::Encoder::Util.demerit_points_1_same_color(modules)).to be == reference.call(modules)
			end
		end
	end
end

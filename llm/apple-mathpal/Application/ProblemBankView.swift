/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

import SwiftUI

struct ProblemBankView: View {
  let selectedGrade: Int
  let onSelect: (String) -> Void

  var body: some View {
    let problems = Self.problems(for: selectedGrade)
    ForEach(Array(problems.enumerated()), id: \.offset) { index, problem in
      Button(action: { onSelect(problem) }) {
        HStack(alignment: .top, spacing: 6) {
          Text("\(index + 1).")
            .font(.caption)
            .foregroundColor(.secondary)
            .frame(width: 16, alignment: .trailing)
          Text(problem)
            .font(.caption)
            .lineLimit(3)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
      .buttonStyle(.plain)
    }
  }

  static func problems(for grade: Int) -> [String] {
    switch grade {
    case 4:
      return [
        "Emma has 24 stickers and gets 18 more. How many stickers does she have?",
        "A baker makes 96 cookies and puts 8 in each bag. How many bags does he fill?",
        "There are 7 rows of chairs with 9 chairs in each row. How many chairs total?",
        "A rectangle is 8 cm long and 5 cm wide. What is its perimeter?",
        "Sam has 50 marbles. He gives 12 to Tom and 8 to Lisa. How many does he have left?",
      ]
    case 5:
      return [
        "A book costs 12.50 dollars and a pen costs 3.75 dollars. How much do they cost together?",
        "A triangle has a base of 10 cm and height of 6 cm. What is its area?",
        "A school has 480 students in 12 classrooms. Each classroom has desks in rows of 8. How many rows per classroom?",
        "A runner completes a lap in 2.5 minutes. How long for 6 laps?",
        "Maria has 3/4 of a yard of ribbon. She uses 1/4. How much is left?",
      ]
    case 6:
      return [
        "The ratio of cats to dogs at a shelter is 3:5. If there are 15 cats, how many dogs are there?",
        "A shirt costs 40 dollars and is 20% off. What is the sale price?",
        "Solve for x: x + 15 = 42",
        "A rectangular garden is 12 feet long and 9 feet wide. How many feet of fence do you need?",
        "A map scale is 1 inch = 25 miles. Two cities are 3 inches apart. What is the real distance?",
      ]
    case 7:
      return [
        "Solve for x: 3x - 7 = 14",
        "A bicycle costs 250 dollars. It is marked down 15%. What is the sale price?",
        "A circle has a radius of 7 cm. What is its area? Use pi = 3.14.",
        "If 5 shirts cost 85 dollars, how much do 8 shirts cost?",
        "A gym charges 25 dollars signup fee plus 10 dollars per month. You have 95 dollars. How many months can you afford?",
      ]
    case 8:
      return [
        "Solve for x: 2(3x - 4) + 5 = 4x + 11",
        "A cylinder has radius 5 cm and height 12 cm. What is its volume? Use pi = 3.14.",
        "A store has buy-2-get-1-free on 15 dollar shirts. You need 7 shirts and have a 10% off coupon. How much do you pay?",
        "Train A leaves at 60 mph. Train B leaves 1 hour later at 80 mph same direction. How many hours until B catches A?",
        "You invest 1000 dollars at 5% annual compound interest. How much after 3 years?",
      ]
    default:
      return []
    }
  }
}

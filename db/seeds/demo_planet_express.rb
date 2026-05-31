# frozen_string_literal: true

return if Rails.env.test?

demo = Demo::PlanetExpressSeeder.call
return unless demo

puts "[demo_planet_express] workspace: #{demo.workspace.name} (/app)"
puts "[demo_planet_express] user: #{Demo::PlanetExpressSeeder::BENDER_EMAIL}"
puts "[demo_planet_express] password: #{Demo::PlanetExpressSeeder::PASSWORD}"

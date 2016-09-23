require 'ffaker'

Post.destroy_all
User.destroy_all

User.create!({
  name: '田中 太郎',
  email: 'test@user.com',
  password: 'test123',
  password_confirmation: 'test123'
})

10.times do
  Post.create!(
    title: FFaker::Lorem.sentence,
    body: FFaker::Lorem.paragraphs.join(' ')
  )
end

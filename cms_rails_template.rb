# Modern Rails Agency Website Template
# Based on Infinity Loop project structure
# Usage: rails new app_name -m path/to/rails_template.rb

# Add gems
gem 'pg' # PostgreSQL adapter
gem 'image_processing'
gem 'mini_magick'

# Admin panel
gem 'avo'

# Email service
gem 'postmark-rails'

# Jobs monitoring
gem 'mission_control-jobs'

# Pagination
gem 'pagy'

# Markdown support
gem 'marksmith'
gem 'commonmarker'
gem 'redcarpet'

# CSS
gem 'tailwindcss-rails'

after_bundle do
  # Initialize git repo
  git :init
  git add: '.'
  git commit: "-m 'Initial commit'"

  # Database setup
  rails_command 'db:create'
  rails_command 'db:migrate'

  # Set up TailwindCSS
  rails_command 'tailwindcss:install'

  # Install Avo
  rails_command 'avo:install'

  # Create active storage tables
  rails_command 'active_storage:install'

  # Create models - using a method to handle file overwrite confirmations
  def generate_model(args)
    generate 'model', args, force: true
  end

  generate_model 'User email_address:string:uniq password_digest:string'
  generate_model 'Session user:references ip_address:string user_agent:string'
  generate_model 'Contact name:string:index email:string:index phone:string message:text services:text'
  generate_model 'Category name:string:uniq label:string'
  generate_model 'Tag name:string:uniq label:string'
  generate_model 'Client name:string industry:string size:string location:string'
  generate_model 'CaseStudy title:string text:text duration:string link:string client:references'
  generate_model 'Article title:string:index slug:string:uniq meta_title:string meta_description:text excerpt:text content:text og_image:string published_at:datetime:index status:string:index reading_time:integer canonical_url:string indexable:boolean view_count:integer share_count:integer'
  generate_model 'NewsletterSubscription email:string first_name:string last_name:string'
  generate_model 'Categorizable category:references categorizable:references{polymorphic}'
  generate_model 'Taggable tag:references taggable:references{polymorphic}'

  # Create controllers - using a method to handle file overwrite confirmations
  def generate_controller(args)
    generate 'controller', args, force: true
  end

  generate_controller 'StaticPages index about contact privacy terms'
  generate_controller 'Articles index show new create edit update destroy --skip-routes'
  generate_controller 'CaseStudies index show new create edit update destroy --skip-routes'
  generate_controller 'Contacts new create --skip-routes'
  generate_controller 'NewsletterSubscriptions create --skip-routes'
  generate_controller 'Sessions new --skip-routes'
  generate_controller 'Passwords new edit --skip-routes'

  # Create mailers
  def generate_mailer(args)
    generate 'mailer', args, force: true
  end

  generate_mailer 'Contacts new_contact'
  generate_mailer 'Passwords reset'

  # Create concerns
  file 'app/models/concerns/nameable.rb', <<~RUBY
    module Nameable
      extend ActiveSupport::Concern

      included do
        validates :name, presence: true, uniqueness: { case_sensitive: false }
        before_validation :set_name_from_label
        before_validation :normalize_name
      end

      private

      def set_name_from_label
        self.name = label if label.present? && name.blank?
      end

      def normalize_name
        if name.present?
          self.name = name.strip
                        .downcase
                        .gsub("/", "-")
                        .gsub(".", "-")
                        .gsub(/[\\s_]+/, "-")
                        .gsub(/[^a-z0-9\\-]/, "")
                        .gsub(/\\-+/, "-")
                        .gsub(/\\A\\-|\\-\\z/, "")
        end
      end
    end
  RUBY

  # Apply concerns to models
  file 'app/models/tag.rb', <<~RUBY
    class Tag < ApplicationRecord
      include Nameable
    #{'  '}
      has_many :taggables, dependent: :destroy
    end
  RUBY

  file 'app/models/category.rb', <<~RUBY
    class Category < ApplicationRecord
      include Nameable
    #{'  '}
      has_many :categorizables, dependent: :destroy
    end
  RUBY

  # Enhance Article model
  file 'app/models/article.rb', <<~RUBY
    class Article < ApplicationRecord
      before_validation :generate_slug

      has_one_attached :main_image
      has_many_attached :additional_images
      has_many :categorizables, as: :categorizable
      has_many :categories, through: :categorizables
      has_many :taggables, as: :taggable
      has_many :tags, through: :taggables

      def formatted_published_date
        day = published_at.day.to_i.ordinalize
        published_at.strftime("\#{day} %B, %Y")
      end

      private

      def generate_slug
        return if title.blank?

        base_slug = title.to_s.parameterize
        counter = 1
        self.slug = base_slug

        while Article.where(slug: slug).where.not(id: id).exists?
          self.slug = "\#{base_slug}-\#{counter}"
          counter += 1
        end
      end
    end
  RUBY

  # Enhance CaseStudy model
  file 'app/models/case_study.rb', <<~RUBY
    class CaseStudy < ApplicationRecord
      belongs_to :client
      has_one_attached :main_image
      has_many_attached :additional_images
      has_many :categorizables, as: :categorizable
      has_many :categories, through: :categorizables
      has_many :taggables, as: :taggable
      has_many :tags, through: :taggables
    end
  RUBY

  # Set up Current model
  file 'app/models/current.rb', <<~RUBY
    class Current < ActiveSupport::CurrentAttributes
      attribute :user
    end
  RUBY

  # Update ApplicationController
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
      include Pagy::Backend
    end
  RUBY

  # Set up ApplicationHelper
  file 'app/helpers/application_helper.rb', <<~RUBY
    module ApplicationHelper
      include Pagy::Frontend
    end
  RUBY

  # Set up Avo resources
  file 'app/avo/resources/article.rb', <<~RUBY
    class Avo::Resources::Article < Avo::BaseResource
      def fields
        field :id, as: :id
        field :title, as: :text
        field :slug, as: :text
        field :meta_title, as: :text
        field :meta_description, as: :textarea
        field :main_image, as: :file, is_image: true
        field :additional_images, as: :files
        field :excerpt, as: :textarea
        field :content, as: :markdown
        field :og_image, as: :text
        field :published_at, as: :date_time
        field :status, as: :text
        field :reading_time, as: :number
        field :canonical_url, as: :text
        field :indexable, as: :boolean
        field :view_count, as: :number
        field :share_count, as: :number
        field :categories, as: :has_many
        field :tags, as: :has_many
      end
    end
  RUBY

  file 'app/avo/resources/case_study.rb', <<~RUBY
    class Avo::Resources::CaseStudy < Avo::BaseResource
      def fields
        field :id, as: :id
        field :title, as: :text
        field :text, as: :markdown
        field :duration, as: :text
        field :link, as: :text
        field :client, as: :belongs_to
        field :main_image, as: :file, is_image: true
        field :additional_images, as: :files
        field :categories, as: :has_many
        field :tags, as: :has_many
      end
    end
  RUBY

  file 'app/avo/resources/category.rb', <<~RUBY
    class Avo::Resources::Category < Avo::BaseResource
      def fields
        field :id, as: :id
        field :name, as: :text
        field :label, as: :text
      end
    end
  RUBY

  file 'app/avo/resources/tag.rb', <<~RUBY
    class Avo::Resources::Tag < Avo::BaseResource
      def fields
        field :id, as: :id
        field :name, as: :text
        field :label, as: :text
      end
    end
  RUBY

  file 'app/avo/resources/client.rb', <<~RUBY
    class Avo::Resources::Client < Avo::BaseResource
      def fields
        field :id, as: :id
        field :name, as: :text
        field :industry, as: :text
        field :size, as: :text
        field :location, as: :text
        field :case_studies, as: :has_many
      end
    end
  RUBY

  file 'app/avo/resources/newsletter_subscription.rb', <<~RUBY
    class Avo::Resources::NewsletterSubscription < Avo::BaseResource
      def fields
        field :id, as: :id
        field :email, as: :text
        field :first_name, as: :text
        field :last_name, as: :text
      end
    end
  RUBY

  # Set up routes
  file 'config/routes.rb', <<~RUBY
    Rails.application.routes.draw do
      mount MissionControl::Jobs::Engine, at: "/jobs"

      resources :articles
      resources :case_studies, path: "case-studies"
      resources :categories, only: [ :index, :show ]
      resources :contacts, only: [ :new, :create ]
      resources :newsletter_subscriptions, only: [ :create ]

      mount Avo::Engine, at: Avo.configuration.root_path

      get "/about", to: "static_pages#about"
      get "/contact", to: "static_pages#contact"
      get "/terms", to: "static_pages#terms"
      get "/privacy", to: "static_pages#privacy"
      get "/work", to: "case_studies#index"

      get "up" => "rails/health#show", as: :rails_health_check

      root "static_pages#index"
    end
  RUBY

  # Configure Avo
  file 'config/initializers/avo.rb', <<~RUBY
    Avo.configure do |config|
      config.root_path = "/avo"
    #{'  '}
      config.set_context do
        # Return a context object that gets evaluated within Avo::ApplicationController
      end

      config.current_user_method do
        Current.user
      end

      config.sign_out_path_name = :session_path
    #{'  '}
      config.authorization_client = nil
      config.explicit_authorization = true
    #{'  '}
      config.click_row_to_view_record = true
    end
  RUBY

  # Configure Pagy
  file 'config/initializers/pagy.rb', <<~RUBY
    # Load Pagy without extras first
    require 'pagy'

    # Then load the extras if needed
    begin
      require 'pagy/extras/bootstrap'
    rescue LoadError
      puts "Skipping Pagy Bootstrap extras - not available"
    end

    begin
      require 'pagy/extras/items'
    rescue LoadError
      puts "Skipping Pagy Items extras - not available"
    end

    begin
      require 'pagy/extras/overflow'
    rescue LoadError
      puts "Skipping Pagy Overflow extras - not available"
    end

    Pagy::DEFAULT[:items] = 10
    Pagy::DEFAULT[:overflow] = :last_page
  RUBY

  # Run seeds - with safety checks
  file 'db/seeds.rb', <<~RUBY
    # Create admin user if it doesn't exist
    unless User.exists?(email_address: 'admin@example.com')
      User.create!(
        email_address: 'admin@example.com',
        password: 'password'
      )
    end

    # Create categories if they don't exist
    ['Web Development', 'Design', 'UI/UX', 'Mobile', 'Marketing'].each do |category_name|
      Category.find_or_create_by!(label: category_name)
    end

    # Create tags if they don't exist
    ['Ruby', 'Rails', 'JavaScript', 'React', 'Vue', 'Tailwind CSS', 'PostgreSQL', 'API'].each do |tag_name|
      Tag.find_or_create_by!(label: tag_name)
    end

    # Only create clients if there are none
    if Client.count == 0
      clients = []
      5.times do |i|
        clients << Client.create!(
          name: "Client \#{i+1}",
          industry: ["Technology", "Healthcare", "Finance", "Education", "Retail"].sample,
          size: ["Small", "Medium", "Enterprise"].sample,
          location: ["New York", "San Francisco", "London", "Berlin", "Tokyo"].sample
        )
      end

      # Create case studies only if there are none
      if CaseStudy.count == 0
        clients.each do |client|
          case_study = CaseStudy.create!(
            title: "Case Study for \#{client.name}",
            text: "This is a case study describing the work we did for \#{client.name}.",
            duration: "\#{rand(1..12)} months",
            link: "https://example.com/case-study-\#{client.id}",
            client: client
          )
    #{'      '}
          # Add categories and tags to case studies
          rand(1..3).times do
            Categorizable.create!(
              category: Category.all.sample,
              categorizable: case_study
            )
    #{'        '}
            Taggable.create!(
              tag: Tag.all.sample,
              taggable: case_study
            )
          end
        end
      end
    end

    # Only create articles if there are none
    if Article.count == 0
      10.times do |i|
        article = Article.create!(
          title: "Article \#{i+1}: How to build modern websites",
          meta_title: "How to build modern websites | Infinity Loop",
          meta_description: "Learn how to build modern websites using the latest technologies.",
          excerpt: "This article covers modern web development techniques.",
          content: "# How to Build Modern Websites\n\nIn this article, we'll explore modern web development techniques...",
          status: ["draft", "published"].sample,
          published_at: rand(1..365).days.ago,
          reading_time: rand(3..15),
          indexable: true,
          view_count: rand(10..1000),
          share_count: rand(5..100)
        )
    #{'    '}
        # Add categories and tags to articles
        rand(1..3).times do
          Categorizable.create!(
            category: Category.all.sample,
            categorizable: article
          )
    #{'      '}
          Taggable.create!(
            tag: Tag.all.sample,
            taggable: article
          )
        end
      end
    end
  RUBY

  # Run seeds
  rails_command 'db:seed'

  # Create README
  file 'README.md', <<~MARKDOWN
    # Modern Rails Agency Website

    This is a professional website template for agencies and freelancers built with Rails 8 and TailwindCSS.

    ## Features

    - Responsive design with TailwindCSS
    - Blog with articles
    - Case studies portfolio
    - Contact form
    - Newsletter subscription
    - Admin panel with Avo
    - Authentication system
    - Markdown support
    - File uploads with Active Storage

    ## Requirements

    - Ruby 3.3.7
    - PostgreSQL
    - Node.js
    - Yarn

    ## Getting Started

    1. Clone the repository
    2. Run `bundle install`
    3. Run `rails db:setup`
    4. Run `bin/dev` to start the server with CSS watching

    ## Admin Access

    Access the admin panel at `/avo` with:
    - Email: admin@example.com
    - Password: password
  MARKDOWN

  # Final commit
  git add: '.'
  git commit: "-m 'Complete Rails template setup'"
end

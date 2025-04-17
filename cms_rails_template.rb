# Modern Rails Agency Website Template
# Based on Infinity Loop project structure
# Usage: rails new app_name -m path/to/rails_template.rb

# Add gems
gem 'propshaft'                # Modern asset pipeline
gem 'importmap-rails'          # JavaScript with ESM import maps
gem 'turbo-rails'              # Hotwire's SPA-like page accelerator
gem 'stimulus-rails'           # Hotwire's modest JavaScript framework
gem 'jbuilder'                 # JSON APIs
gem 'bcrypt', '~> 3.1.7'       # Password hashing
gem 'solid_cache'              # Database-backed cache adapter
gem 'solid_queue'              # Database-backed job queue
gem 'solid_cable'              # Database-backed action cable
gem 'bootsnap', require: false # Boot time reduction
gem 'kamal', require: false    # Docker deployment
gem 'thruster', require: false # HTTP asset caching/compression
gem 'pg'                       # PostgreSQL adapter
gem 'activestorage'
gem 'image_processing', '~> 1.2'
gem 'mini_magick'

# Admin panel
gem 'avo', '>= 3.2.1'

# Email service
gem 'postmark-rails'

# Jobs monitoring
gem 'mission_control-jobs'

# Pagination
gem 'pagy', '~> 9.3'

# Markdown support
gem 'marksmith'
gem 'commonmarker'
gem 'redcarpet'

# CSS
gem 'tailwindcss-rails', '~> 3.1'

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

  # Install importmap
  rails_command 'importmap:install'

  # Install Avo
  rails_command 'avo:install'

  # Create active storage tables
  rails_command 'active_storage:install'

  # Create models
  generate 'model User email_address:string:uniq password_digest:string'
  generate 'model Session user:references ip_address:string user_agent:string'
  generate 'model Contact name:string:index email:string:index phone:string message:text services:text'
  generate 'model Category name:string:uniq label:string'
  generate 'model Tag name:string:uniq label:string'
  generate 'model Client name:string industry:string size:string location:string'
  generate 'model CaseStudy title:string text:text duration:string link:string client:references'
  generate 'model Article title:string:index slug:string:uniq meta_title:string meta_description:text excerpt:text content:text og_image:string published_at:datetime:index status:string:index reading_time:integer canonical_url:string indexable:boolean view_count:integer share_count:integer'
  generate 'model NewsletterSubscription email:string first_name:string last_name:string'
  generate 'model Categorizable category:references categorizable:references{polymorphic}'
  generate 'model Taggable tag:references taggable:references{polymorphic}'

  # Create controllers
  generate 'controller StaticPages index about contact privacy terms'
  generate 'controller Articles index show new create edit update destroy --skip-routes'
  generate 'controller CaseStudies index show new create edit update destroy --skip-routes'
  generate 'controller Contacts new create --skip-routes'
  generate 'controller NewsletterSubscriptions create --skip-routes'
  generate 'controller Sessions new --skip-routes'
  generate 'controller Passwords new edit --skip-routes'

  # Create mailers
  generate 'mailer Contacts new_contact'
  generate 'mailer Passwords reset'

  # Set up Active Storage
  rails_command 'active_storage:install'

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
      
      has_many :taggables, dependent: :destroy
    end
  RUBY

  file 'app/models/category.rb', <<~RUBY
    class Category < ApplicationRecord
      include Nameable
      
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

  # Authentication concern
  file 'app/controllers/concerns/authentication.rb', <<~RUBY
    module Authentication
      extend ActiveSupport::Concern

      included do
        before_action :authenticate
      end

      class_methods do
        def allow_unauthenticated_access(to: nil, except: nil, only: nil)
          skip_before_action :authenticate, to: to, except: except, only: only
        end
      end

      private
        def authenticate
          if authenticated_user = User.find_by(id: session[:user_id])
            Current.user = authenticated_user
          else
            redirect_to new_session_path
          end
        end
    end
  RUBY

  # Update ApplicationController
  file 'app/controllers/application_controller.rb', <<~RUBY
    class ApplicationController < ActionController::Base
      include Authentication
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

      resource :session
      resources :passwords, param: :token
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
      
      config.set_context do
        # Return a context object that gets evaluated within Avo::ApplicationController
      end

      config.current_user_method do
        Current.user
      end

      config.sign_out_path_name = :session_path
      
      config.authorization_client = nil
      config.explicit_authorization = true
      
      config.click_row_to_view_record = true
    end
  RUBY

  # Configure Pagy
  file 'config/initializers/pagy.rb', <<~RUBY
    require 'pagy/extras/bootstrap'
    require 'pagy/extras/items'
    require 'pagy/extras/overflow'

    Pagy::DEFAULT[:items] = 10
    Pagy::DEFAULT[:overflow] = :last_page
  RUBY

  # Create Procfile.dev
  file 'Procfile.dev', <<~PROCFILE
    web: bin/rails server
    css: bin/rails tailwindcss:watch
  PROCFILE

  # Create seeds.rb
  file 'db/seeds.rb', <<~RUBY
    # Create admin user
    User.create!(
      email_address: 'admin@example.com',
      password: 'password'
    )

    # Create categories
    ['Web Development', 'Design', 'UI/UX', 'Mobile', 'Marketing'].each do |category|
      Category.create!(label: category)
    end

    # Create tags
    ['Ruby', 'Rails', 'JavaScript', 'React', 'Vue', 'Tailwind CSS', 'PostgreSQL', 'API'].each do |tag|
      Tag.create!(label: tag)
    end

    # Create clients
    clients = []
    5.times do |i|
      clients << Client.create!(
        name: "Client \#{i+1}",
        industry: ["Technology", "Healthcare", "Finance", "Education", "Retail"].sample,
        size: ["Small", "Medium", "Enterprise"].sample,
        location: ["New York", "San Francisco", "London", "Berlin", "Tokyo"].sample
      )
    end

    # Create case studies
    clients.each do |client|
      case_study = CaseStudy.create!(
        title: "Case Study for \#{client.name}",
        text: "This is a case study describing the work we did for \#{client.name}.",
        duration: "\#{rand(1..12)} months",
        link: "https://example.com/case-study-\#{client.id}",
        client: client
      )
      
      # Add categories and tags to case studies
      rand(1..3).times do
        Categorizable.create!(
          category: Category.all.sample,
          categorizable: case_study
        )
        
        Taggable.create!(
          tag: Tag.all.sample,
          taggable: case_study
        )
      end
    end

    # Create articles
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
      
      # Add categories and tags to articles
      rand(1..3).times do
        Categorizable.create!(
          category: Category.all.sample,
          categorizable: article
        )
        
        Taggable.create!(
          tag: Tag.all.sample,
          taggable: article
        )
      end
    end
  RUBY

  # Run seeds
  rails_command 'db:seed'

  # Set up application layout
  file 'app/views/layouts/application.html.erb', <<~HTML
    <!DOCTYPE html>
    <html class="h-full scroll-smooth antialiased" lang="<%= I18n.locale %>">
      <head>
        <title><%= content_for?(:title) ? yield(:title) : "Modern Rails Agency" %></title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        
        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
      </head>
      <body class="flex h-full flex-col bg-white">
        <%= render "shared/header" %>
        <main class="grow">
          <%= yield %>
        </main>
        <%= render "shared/footer" %>
      </body>
    </html>
  HTML

  # Setup header partial
  file 'app/views/shared/_header.html.erb', <<~HTML
    <header class="bg-white">
      <nav class="mx-auto flex max-w-7xl items-center justify-between p-6 lg:px-8" aria-label="Global">
        <div class="flex lg:flex-1">
          <a href="/" class="-m-1.5 p-1.5">
            <span class="sr-only">Your Company</span>
            <img class="h-8 w-auto" src="/logo.png" alt="">
          </a>
        </div>
        <div class="flex lg:hidden">
          <button type="button" class="-m-2.5 inline-flex items-center justify-center rounded-md p-2.5 text-gray-700">
            <span class="sr-only">Open main menu</span>
            <svg class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" aria-hidden="true">
              <path stroke-linecap="round" stroke-linejoin="round" d="M3.75 6.75h16.5M3.75 12h16.5m-16.5 5.25h16.5" />
            </svg>
          </button>
        </div>
        <div class="hidden lg:flex lg:gap-x-12">
          <a href="/" class="text-sm font-semibold leading-6 text-gray-900">Home</a>
          <a href="/about" class="text-sm font-semibold leading-6 text-gray-900">About</a>
          <a href="/work" class="text-sm font-semibold leading-6 text-gray-900">Work</a>
          <a href="/articles" class="text-sm font-semibold leading-6 text-gray-900">Blog</a>
          <a href="/contact" class="text-sm font-semibold leading-6 text-gray-900">Contact</a>
        </div>
      </nav>
    </header>
  HTML

  # Setup footer partial
  file 'app/views/shared/_footer.html.erb', <<~HTML
    <footer class="bg-white">
      <div class="mx-auto max-w-7xl px-6 py-12 md:flex md:items-center md:justify-between lg:px-8">
        <div class="flex justify-center space-x-6 md:order-2">
          <a href="#" class="text-gray-400 hover:text-gray-500">
            <span class="sr-only">Twitter</span>
            <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path d="M8.29 20.251c7.547 0 11.675-6.253 11.675-11.675 0-.178 0-.355-.012-.53A8.348 8.348 0 0022 5.92a8.19 8.19 0 01-2.357.646 4.118 4.118 0 001.804-2.27 8.224 8.224 0 01-2.605.996 4.107 4.107 0 00-6.993 3.743 11.65 11.65 0 01-8.457-4.287 4.106 4.106 0 001.27 5.477A4.072 4.072 0 012.8 9.713v.052a4.105 4.105 0 003.292 4.022 4.095 4.095 0 01-1.853.07 4.108 4.108 0 003.834 2.85A8.233 8.233 0 012 18.407a11.616 11.616 0 006.29 1.84" />
            </svg>
          </a>
          <a href="#" class="text-gray-400 hover:text-gray-500">
            <span class="sr-only">GitHub</span>
            <svg class="h-6 w-6" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
              <path fill-rule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clip-rule="evenodd" />
            </svg>
          </a>
        </div>
        <div class="mt-8 md:order-1 md:mt-0">
          <p class="text-center text-xs leading-5 text-gray-500">&copy; <%= Date.today.year %> Modern Rails Agency. All rights reserved.</p>
        </div>
      </div>
    </footer>
  HTML

  # Setup home page
  file 'app/views/static_pages/index.html.erb', <<~HTML
    <div class="relative isolate overflow-hidden bg-white">
      <div class="mx-auto max-w-7xl px-6 pb-24 pt-10 sm:pb-32 lg:flex lg:px-8 lg:py-40">
        <div class="mx-auto max-w-2xl lg:mx-0 lg:max-w-xl lg:flex-shrink-0 lg:pt-8">
          <h1 class="mt-10 text-4xl font-bold tracking-tight text-gray-900 sm:text-6xl">Modern Rails Agency Template</h1>
          <p class="mt-6 text-lg leading-8 text-gray-600">
            A professional website template for agencies and freelancers built with Rails 8 and TailwindCSS.
          </p>
          <div class="mt-10 flex items-center gap-x-6">
            <a href="/about" class="rounded-md bg-indigo-600 px-3.5 py-2.5 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600">Learn more</a>
            <a href="/contact" class="text-sm font-semibold leading-6 text-gray-900">Contact us <span aria-hidden="true">→</span></a>
          </div>
        </div>
      </div>
    </div>
  HTML

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
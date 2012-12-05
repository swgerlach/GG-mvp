class Event < ActiveRecord::Base

	belongs_to :user
	validates_presence_of :topic, :host, :description, :skill_list, :tool_list, :location_address, :age_min, :age_max
	validates_inclusion_of :age_min, :in => 0..99
  validates_numericality_of :registration_min

	attr_accessible :title, :topic, :host, :kind, :description, :begins_at, :begins_at_date, :begins_at_time, :ends_at, :ends_at_date, :ends_at_time, :skill_list, :tool_list, :requirement_list, :other_needs, :hours, :hours_per, :location_address, :location_address2, :location_city, :location_state, :location_zipcode, :location_private, :location_nbrhood, :location_varies, :age_min, :age_max, :registration_min, :registration_max, :price, :registration_ends_at
	before_save :generate_title
	
  auto_strip_attributes :skills, :tools, :requirements

	acts_as_taggable
	acts_as_taggable_on :skills, :tools, :requirements



  attr_accessible :stripe_card_token
  attr_accessor :stripe_card_token


	def generate_title
  	self.title = "#{self.topic} Apprenticeship with #{self.host}"
	end
	
	def begins_at=(new_date)
  	write_attribute(:begins_at, Chronic::parse(new_date).strftime('%Y-%m-%d %H:%M:%S'))
	end

	def ends_at=(new_date)
  	write_attribute(:ends_at, Chronic::parse(new_date).strftime("%Y-%m-%d %H:%M:%S"))
	end
	
  def registration_ends_at=(new_date)
    write_attribute(:registration_ends_at, Chronic::parse(new_date).strftime("%Y-%m-%d %H:%M:%S"))
  end

  def process_payment
    logger.info "Processing payment"
    unless charge_id.present?
      charge = Stripe::Charge.create(
        :amount => 900, # amount in cents, again
        :currency => "usd",
        :card => stripe_card_token,
        :description => "Apprenticeship payment from #{self.user.email}"
      )
      self.charge_id = charge.id
      logger.info "Processed payment #{charge.id}"
    end	
  rescue Stripe::InvalidRequestError => e
    logger.error "Stripe error while creating charge: #{e.mesage}"
    errors.add :base, "There was a problem with your credit card."
  end
	
	state_machine :state, :initial => :started do
  	
  	state :started do
  	end
  	
  	state :pending do
  	  validates_presence_of :charge_id
  	end
  	
  	state :accepted do
  	end
  	
  	state :canceled do
  	end
  	
  	event :reject do
    	transition :pending => :started
  	end
  	
  	event :revoke do
    	transition :accepted => :started
  	end
  	
  	event :submit do
    	transition :started => :pending
    end
    
    event :accept do
      transition :pending => :accepted
    end
    
    event :cancel do
      transition all => :canceled
    end
    
  end
  	
end

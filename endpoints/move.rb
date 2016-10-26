module Endpoints
  class Move < Base

    set :model, User

    get '/' do
      current_location    = API::Locations.get(current_user.location)

      moves = []

      current_location['moves'].each do |move|
        next if move['transport'] == 'tram' && current_user.money < move['cost']
        moves << move
      end

      moves = moves + bike_moves(current_location) if (current_user.bike_tokens > 0)
      moves = moves.uniq

      response.set_data(moves)
    end

    def bike_moves(current_location)

      moves = []

      current_location['moves'].each do |move|

        next unless move['transport'] == 'walk'

        target_location     = API::Locations.get(move['location'])

          target_location['moves'].each do |bike_move|

            next unless bike_move['transport'] == 'walk'
            next if bike_move['location'] == current_location['id']

            moves << {
                        'transport' => 'bike',
                        'location'  => bike_move['location']
                     }
          end
      end

      moves

    end

    post '/:location_id' do

      transports = {
                      'walk'    => 'walked',
                      'bike'    => 'cycled',
                      'tram'    => 'caught the tram'
                   }

      check_turn

      target_location_id  = params[:location_id]
      current_location    = API::Locations.get(current_user.location)
      target_location     = API::Locations.get(target_location_id)
      valid_move          = false
      move_transport      = 'unknown'

      logger.debug "user attempting to move from #{current_user.location} to #{target_location_id}"

      current_location['moves'].each do |move|
        if move['location'].to_s == target_location_id.to_s
          valid_move     = true
          move_transport = move['transport']
        end
      end

      if (current_user.bike_tokens > 0)
        bike_moves(current_location).each do |move|
          if move['location'].to_s == target_location_id.to_s
            valid_move      = true
            move_transport  = 'bike'
          end
        end
      end

      response.fail "invalid move" unless valid_move

      case move_transport
      when 'bike'
        current_user.bike_tokens -= 1
      when 'tram'
        current_user.money -= 10
      end

      if current_user.type == 'criminal'
        description = "#{transports[move_transport]}"
      else
        description = "#{transports[move_transport]} from #{current_user.location} to #{target_location_id}"
      end

      current_user.create_event({
                                  type:         :move,
                                  event:        move_transport,
                                  description:  description
                               })

      current_user.location     = target_location_id
      current_user.last_move_at = Time.now
      current_user.save_changes

      User.all.each do |user|
        game_over if (user.location == current_user.location) && (user.type != current_user.type)
      end

      random_mugging

# binding.pry if current_location['id'] == '21'
      if current_location['triggers']
        current_location['triggers'].each do |trigger_id, trigger|
          send("perform_#{trigger['type']}_trigger")
        end
      end

      update_turn

      response.add_data(current_user)
    end

    def perform_stuck_trigger

      logger.info "stuck trigger"

      current_user.turn += 1
      current_user.save_changes
      current_user.create_event({
                                  type:         'move',
                                  event:        'stuck',
                                  description:  'got stuck in a queue'
                                })
    end

    def random_mugging

      if rand(20) == 0
        logger.warn "mugged by a junkie!"

        options = [ :money, :bike_tokens, :tram_tokens ]

        for option_type in options

          if current_user[option_type] > 0
            logger.info "took your #{option_type}"
            current_user[option_type] = 0
            break
          end
        end

        current_user.create_event({
                                    type:         :mugging,
                                    event:        option_type,
                                    description:  "mugged by a junkie"
                                 })
      end
    end

    post '/' do
      deny_access
    end
  end
end

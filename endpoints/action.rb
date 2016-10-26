module Endpoints
  class Action < Base

    post '/:id' do

      check_turn

      deny_access "no actions here" unless current_location['actions']

      action_id = params[:id]

      current_location['actions'].each do |id, action|
        next unless action_id == id

        logger.debug "user performing action #{id}"
        logger.debug action

        send("perform_#{action['type']}_action", action)

      end

      update_turn

      response.add_data(current_user)

    end

    def perform_purchase_action(action)

      logger.info "performing a token purchase"

      token_type = action['token_type'] + '_tokens'

      if current_user.money.to_i < action['token_cost']
        logger.warn "user doesn't have enough money"

        response.fail

      end

      current_user.money -= action['token_cost']
      current_user.send(token_type + '=', current_user.send(token_type) + 1)
      current_user.save_changes

      current_user.create_event({
                                  type:         :purchase,
                                  event:        token_type,
                                  description:  "purchased #{token_type} :)"
                                 })

    end

    def perform_atm_action(action)

      logger.info "drawing money from the ATM"

      current_user.create_event({
                                  type:         :money,
                                  event:        :cash,
                                  description:  "drew money from the ATM"
                                 })

      current_user.money += 20
      current_user.save
    end

    def perform_hide_action(action)

      logger.info "hiding until turn #{current_user.turn + 3}"

      redis.set('amsterdam:criminal:hide', (current_user.turn + 3).to_s)

    end

  end
end

module API

  class Locations

    @@locations = {}
    @@logger    = nil

    def self.locations
      @@locations
    end

    def self.locations=(locations)
      @@locations = locations
    end

    def self.logger
      @@logger
    end

    def self.logger=(logger)
      @@logger = logger
    end

    def self.get(id)
      @@locations[id.to_s]
    end

    def self.parse_locations

      locations    = YAML.load_file('config/common/locations.yaml')

      locations.each do |id, location|

        next unless location['moves'] rescue binding.pry

        location['moves'].each do |move|
          move['location'] = move['location'].to_s
          next unless move['transport'] == 'walk'
          next if locations[move['location']] == id

          logger.debug "location #{id}"

          locations[move['location']]['moves'] << { 'location' => id, 'transport' => 'walk' }
        end
      end

      f   = File.open("../www/ams.kml")
      doc = Nokogiri::XML(f)
      doc.remove_namespaces!
      f.close

      points = {}
      placemarks = doc.css('Placemark')

      placemarks.each do |placemark|

        next if placemark.css('Point').empty?

        point_id = placemark.css('name').children.first.to_s

        points[point_id] = {
                              'walk'    => placemark.css('description').children.first.text.split(','),
                              'coords'  => placemark.css('Point').css('coordinates').children.first.to_s.split(','),
                           }
      end

      points.each do |point_id, point|

        moves = []

        point['walk'].each do |i|
          moves << {
                     'location'     => i,
                     'transport'    => 'walk',
                   }
        end

        unless locations[point_id]
          logger.warn "no matching location for point '#{point_id}', creating one"

          locations[point_id] = {
                                  'id'        => point_id,
                                  'moves'     => moves.uniq,
                                  'coords'    => {
                                                  'lat'     => point['coords'][0],
                                                  'long'    => point['coords'][1],
                                                  }
                                }
          next
        end


        locations[point_id]['id']             = point_id
        locations[point_id]['coords']         = {}
        locations[point_id]['coords']['lat']  = point['coords'][0]
        locations[point_id]['coords']['long'] = point['coords'][1]

        locations[point_id]['moves'] ||= []
        locations[point_id]['moves'] = (locations[point_id]['moves'] + moves).uniq rescue binding.pry
      end

      @@locations = locations

    end
  end
end

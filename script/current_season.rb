def current_season
                season = Rails.cache.fetch("seasoncur/all", :expires_in => 30.minutes, :raw => true) do
                        season = nil
                        RANK_REGIONS.each_value do |region|
                                region_season = Rails.cache.read("seasoncur/#{region}", :raw => true).to_i
                                next unless region_season > 0
                                if !season or season < region_season
                                        season = region_season
                                end
                        end

                        unless season
                                char = Character.first(:select => "MAX(season) as season")
                                season = char && char.season || 9
                        end

                        season
                end.to_i
                season = 9 unless season > 0
		season
end

defmodule MarketFetching.UniswapFetcher do
	@moduledoc """
		Fetches the Uniswap market and updates the global Market accordingly.
	"""
	use Task, restart: :permanent

	import MarketFetching.Util
	alias MarketFetching.{Pair, ExchangeMarket, PairMarketData}

	@base_api_url "https://uniswap-analytics.appspot.com/api/v1"
	@market_endpoint "ticker"

	@poll_interval 10_000

	@currencies %{
		"BAT" => "0x0d8775f648430679a709e98d2b0cb6250d2887ef",
		"DAI" => "0x89d24a6b4ccb1b6faa2625fe562bdd9a23260359",
		"MKR" => "0x9f8f72aa9304c8b593d555f12ef6589cc3a579a2",
		"SPANK" => "0x42d6622dece394b54999fbd73d108123806f6a18",
		"ZRX" => "0xe41d2489571d322189246dafa5ebde1f4699f498",
	}

	@exchange_addresses %{
		"BAT" => "0x2E642b8D59B45a1D8c5aEf716A84FF44ea665914",
		"DAI" => "0x09cabEC1eAd1c0Ba254B09efb3EE13841712bE14",
		"MKR" => "0x2C4Bd064b998838076fa341A83d007FC2FA50957",
		"SPANK" => "0x4e395304655F0796bc3bc63709DB72173b9DdF98",
		"ZRX" => "0xaE76c84C9262Cdb9abc0C2c8888e62Db8E22A0bF",
	}

	# Makes sure private functions are testable.
	@compile if Mix.env == :test, do: :export_all

	def start_link(_arg) do
		Task.start_link(__MODULE__, :poll, [])
	end

	def poll() do
		Stream.interval(@poll_interval)
		|> Stream.map(fn _x -> exchange_market() end)
		|> Enum.each(fn x -> maybe_update(x) end)
	end

	def exchange_market() do
    c = @currencies

		complete_market =
			Enum.reduce(@exchange_addresses, [], fn ({t, ea}, acc) ->
				#IO.inspect("#{@base_api_url}/#{@market_endpoint}?exchangeAddress=#{ea}")
				case fetch_and_decode("#{@base_api_url}/#{@market_endpoint}?exchangeAddress=#{ea}") do
					{:ok, p} ->
						%{
							"lastTradePrice" => lp,
							"price" => cb = ca,
							"tradeVolume" => bv
						} = p

						[bs, qs] = ["ETH", t]
						[ba, qa] = [eth_address(), c[t]]

						case valid_values?(strings: [bs, qs, ba, qa], numbers: [lp, cb, ca, bv]) do
							true ->
								[market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) | acc]
							false ->
								acc
						end
					{:error, _message} ->
						nil
				end
			end)

		%ExchangeMarket{
			exchange: :uniswap,
			market: complete_market
		}
	end

	defp market_pair([bs, qs, ba, qa, lp, cb, ca, bv]) do
		%Pair{
			base_symbol: bs,
			quote_symbol: qs,
			base_address: ba,
			quote_address: qa,
			market_data: %PairMarketData{
				exchange: :uniswap,
				last_price: :math.pow(parse_float(lp), -1),
				current_bid: :math.pow(parse_float(cb), -1),
				current_ask: :math.pow(parse_float(ca), -1),
				base_volume: :math.pow(parse_float(bv), -18)
			}
		}
	end
end

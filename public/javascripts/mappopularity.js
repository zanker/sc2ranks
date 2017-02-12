$(document).ready(function() {
	for( var i in games_data ) {
		games_data[i][0] = Date.parse(games_data[i][0])
	}
	
	var chart = new Highcharts.Chart({
		chart: {
			renderTo: "container",
			margin: [30, 25, 40, 60],
			zoomType: "x",
			width: "958",
			height: "350"
		},
		plotOptions: {
			series: {
				dataLabels: {
					enabled: true,
					x: 5,
					formatter: function() {
						return this.point.name
					},
					color: "#f3c90c"
				}
			}
		},
		title: {
			text: null
		},
		xAxis: {
			type: "datetime",
			startOnTick: true,
			allowDecimals: false,
			labels: {
				rotation: -20,
				y: 22
			}
		},
		yAxis: [{
			min: 0,
			allowDecimals: false,
			labels: {
				y: 4,
				style: {
					color: "#5994D9"
				}
			},
			title: {
				text: null
			}
		}],
		tooltip: {
			formatter: function() {
				return this.y + (this.y == 1 ? " game" : " games")
			}
		},
		legend: {
			enabled: false
		},
		series: [{
			name: "Games",
			type: "spline",
			data: games_data
		}]
	});
})


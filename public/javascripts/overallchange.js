$(document).ready(function() {
	for( var region in population_series ) {
		for( var i in population_series[region].data ) {
			population_series[region].data[i][0] = Date.parse(population_series[region].data[i][0])
		}
	}
	
	var chart = new Highcharts.Chart({
		credits: { enabled: false },  
		chart: {
			renderTo: "population",
			margin: [20, 175, 30, 80]
		},
		title: {
			text: null
		},
		xAxis: {
			type: "datetime",
			allowDecimals: false,
			tickInterval: 24 * 3600 * 1000,
			labels: {
				y: 22
			}
		},
		yAxis: [{
			min: 0,
			labels: {
				y: 4,
				style: {
					color: "#f3c90c"
				}
			},
			title: {
				text: null
			}
		}],
		tooltip: {
			formatter: function() {
				return this.y + " players"
			}
		},
		legend: {
			layout: "vertical",
			style: {
				left: "auto",
				bottom: "auto",
				right: "3px",
				top: "10px"
			}
		},
		series: population_series,
	});
})


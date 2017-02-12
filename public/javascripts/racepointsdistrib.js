$(document).ready(function() {
	var chart = {
		credits: { enabled: false },  
		chart: {
			margin: [38, 5, 25, 45],
			defaultSeriesType: "column"
		},
		colors: [
			"#8E8E8E",
			"#EBB82A",
			"#351EC7",
			"#911FAD"
		],
		title: {
			text: null
		},
		xAxis: {
			endOnTick: false,
			startOnTick: false,
			labels: {
				y: 20,
				style: {
					color: "#f3c90c"
				}
			}
		},
		yAxis: {
			max: 1,
			tickInterval: 0.20,
			title: {
				text: null
			},
			labels: {
				formatter: function() {
					return (this.value * 100).toFixed() + "%"
				}
			}
		},
		tooltip: {
			formatter: function() {
				return this.series.name + ": " + (this.y * 100).toFixed(2) + "%"
			}
		},
		legend: {
			layout: "horizontal",
			style: {
				left: "auto",
				bottom: "auto",
				right: "auto",
				top: "-5px"
			}
		},
		plotOptions: {
			bar: {
				groupPadding: 0,
				animation: false
			}
		}
	}
	
	for( var i=0; i <= 5; i++ ) {
		chart.chart.renderTo = "container" + i
		chart.series = points_data[i]
		chart.xAxis.categories = points_slice[i]
		new Highcharts.Chart(chart)
	}
})
$(document).ready(function() {
	for( var i in points_all_data ) {
		for( var point in points_all_data[i].data ) {
			points_all_data[i].data[point][0] = Date.parse(points_all_data[i].data[point][0])
		}
	}

	for( var i in points_recent_data ) {
		for( var point in points_recent_data[i].data ) {
			points_recent_data[i].data[point][0] = Date.parse(points_recent_data[i].data[point][0])
		}
	}
	
	var chart = {
		credits: { enabled: false },  
		chart: {
			margin: [35, 150, 40, 60],
			zoomType: "x"
		},
		plotOptions: {
			series: {
				dataLabels: {
					enabled: true,
					x: 5,
					formatter: function() {
						return this.point.name
					}
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
		yAxis: {
			allowDecimals: false,
			labels: {
				y: 4,
				style: {
					color: "#f3c90c"
				}
			},
			title: {
				text: null
			}
		},
		tooltip: {
			formatter: function() {
				return this.series.name + " - " + this.y + " points"
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
		}
	}
	
	chart.series = points_recent_data
	chart.chart.renderTo = "container24"
	chart.yAxis.tickInterval = 50
	var recent_time = new Highcharts.Chart(chart)
	
	chart.series = points_all_data
	chart.chart.renderTo = "containerall"
	chart.yAxis.tickInterval = 100
	var all_time = new Highcharts.Chart(chart)
})


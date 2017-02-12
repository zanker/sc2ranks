$(document).ready(function() {
	var chart = new Highcharts.Chart({
		credits: { enabled: false },  
		chart: {
			margin: [38, 5, 30, 40],
			renderTo: "container",
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
			categories: xaxis_list,
			endOnTick: false,
			startOnTick: false,
			labels: {
				y: 22,
				style: {
					fontSize: "17px",
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
		},
		series: race_distribution
	})
})
$(document).ready(function() {
	for( var i in points_data ) { points_data[i].x = Date.parse(points_data[i].x) }
	for( var i in ranks_data ) { ranks_data[i][0] = Date.parse(ranks_data[i][0]) }
	
	var chart_config = {
		credits: { enabled: false }, 
		chart: {
			animation: false,
			ignoreHiddenSeries: false,
			renderTo: "container",
			margin: [20, 85, 45, 80],
			zoomType: "x",
			width: ($(".adboxbg").length == 0 && "958" || "1138"),
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
			pointInterval: 24 * 3600 * 1000,
			labels: {
				rotation: -30,
				y: 22
			}
		},
		yAxis: [{
			labels: {
				y: 4,
				style: {
					color: "#5994D9"
				}
			},
			title: {
				text: "Points"
			}
		},
		{
			min: 0,
			allowDecimals: false,
			opposite: true,
			reversed: true,
			labels: {
				y: 4,
				style: {
					color: "#E36562"
				}
			},
			title: {
				text: "World rank"
			}
		}],
		tooltip: {
			formatter: function() {
				if( this.series.name == "Points" ) {
					return this.y + " points"
				} else {
					return this.y + " world rank"
				}
			}
		},
		legend: {
			enabled: false
		},
		series: [{
			name: "Points",
			type: "line",
			data: points_data
		},
		{
			name: "World rank",
			type: "line",
			yAxis: 1,
			data: ranks_data
		}]
	}
	
	var chart = new Highcharts.Chart(chart_config);
	
	var original_href = location.href.replace(/#(.+)/, "");
	function update_graph() {
		$("#historyimg").show();
		chart.showLoading("Loading...");

		data = {};
		if( !location.href.match("#alltime$") ) {
			data.month = $("#log_picker_month").val();
			data.year = $("#log_picker_year").val();
		}

		$.ajax({
			type: "POST",
			url: "/team/history/" + team_id,
			data: data,
			success: function(data) {
				if( data.points.length == 0 ) {
					if( $("#nodata").length == 0 ) {
						$("<div class='darkbg' id='nodata'></span>").appendTo(".teamgraph");
					}
					
					$("#nodata").text("No historical data found for " + $("#log_picker_month").val() + "/" + $("#log_picker_year").val());
					$("#container").hide();
					$("#nodata").show();
					return;
				}
				
				$("#container").show();
				$("#nodata").hide();
				
				for( var i in data.points ) { data.points[i].x = Date.parse(data.points[i].x) }
				for( var i in data.ranks ) { data.ranks[i][0] = Date.parse(data.ranks[i][0]) }

				chart_config.series[0].data = data.points;
				chart_config.series[1].data = data.ranks;
				
				chart.destroy();
				chart = new Highcharts.Chart(chart_config);

				points_data = null;
				ranks_data = null;
			},
			complete: function() {
				$("#historyimg").hide();
				chart.hideLoading();
			}
		});
	}

	// Load whatever they looked at last
	if( location.href.match("#alltime$") ) {
		update_graph();
	} else {
		date = location.href.match("#([0-9]+):([0-9]+)");
		if( date && ( $("#log_picker_month").val() != date[1] || $("#log_picker_year").val() != date[2] ) ) {
			$("#log_picker_month").val(date[1]);
			$("#log_picker_year").val(date[2]);
			update_graph();
		}
	}
	
	$("#log_picker_all").click(function() {
		if( !location.href.match("#alltime$") ) {
			location.href = original_href + "#alltime";
			update_graph();
		}
	});
	$("#log_picker_month").change(function() {
		location.href = original_href + "#" + $("#log_picker_month").val() + ":" + $("#log_picker_year").val();
		update_graph();
	});
	$("#log_picker_year").change(function() {
		location.href = original_href + "#" + $("#log_picker_month").val() + ":" + $("#log_picker_year").val();
		update_graph();
	});
})


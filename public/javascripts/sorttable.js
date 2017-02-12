var rows = []
var table_data = []
var sort_id = "rank"
var sort_asc = 1


function update_table() {
	$("[class^='tblrow']").each(function(id, row) {
		row = $(row)
		for( var column in table_data[id].html ) {
			row.find("." + column).html(table_data[id].html[column])
		}
	})
}

function scrape_table() {
	// Scrape all of the data out 
	$("[class^='tblrow']").each(function(id, row) {
		row = $(row)
		var data = {html: {}}
		data.html.rank = row.find(".rank").text()
		data.rank = data.html.rank.replace(",", "")
		
		data.region = row.find(".region a").text() || row.find(".region").text()
		data.html.region = row.find(".region").html()
		
		for( var i=0; i < bracket; i++ ) {
			data["character" + i] = row.find(".character" + i + " a").text().toLowerCase()
			data.html["character" + i] = row.find(".character" + i).html()
		}
		
		data.html.teams = row.find(".teams").text()
		data.teams = data.html.teams.replace(",", "")

		data.html.points = row.find(".points").html()
		if( data.html.points ) data.points = row.find(".points").text().replace(",", "").match("([0-9]+)")[0]
		
		data.html.games = row.find(".games").text()
		data.games = data.html.games.replace(",", "")

		data.html.wins = row.find(".wins").text()
		data.wins = data.html.wins.replace(",", "")

		data.html.oldwins = row.find(".oldwins").text()
		data.oldwins = data.html.oldwins.replace(",", "")

		data.html.newwins = row.find(".newwins").text()
		data.newwins = data.html.newwins.replace(",", "")

		data.html.losses = row.find(".losses").text()
		data.losses = data.html.losses.replace(",", "")

		data.html.oldpoints = row.find(".oldpoints").text()
		data.oldpoints = data.html.oldpoints.replace(",", "")

		data.html.newpoints = row.find(".newpoints").text()
		data.newpoints = data.html.newpoints.replace(",", "")

		data.html.oldlosses = row.find(".oldlosses").text()
		data.oldlosses = data.html.oldlosses.replace(",", "")

		data.html.newlosses = row.find(".newlosses").text()
		data.newlosses = data.html.newlosses.replace(",", "")

		data.html.oldleague = row.find(".oldleague").html()
		data.oldleague = row.find(".oldleague").text()

		data.html.newleague = row.find(".newleague").html()
		data.newleague = row.find(".newleague").text()

		data.html.ratio = row.find(".ratio").text()
		data.ratio = data.html.ratio.replace(".", "").replace("%", "")

		data.html.achievements = row.find(".achievements").text()
		data.achievements = parseInt(data.html.achievements.replace(",", ""))
		
		data.html.maptype = row.find(".maptype").html()
		data.maptype = row.find(".maptype").text()
		
		data.html.bracket = row.find(".bracket").html()
		data.bracket = row.find(".bracket").text()
		
		data.html.results = row.find(".results").html()
		data.results = row.find(".results").html()
		
		data.division = row.find(".division a").text()
		data.html.division = row.find(".division").html()

		if( typeof(data.division) != "string" || data.division == "" ) {
			data.division = row.find(".divisiongm").text().replace("#", "")
			data.html.division = row.find(".divisiongm").html()
		}
		
		data.html.age = row.find(".age").text()
		
		match = data.html.age.match(/([0-9]+)/)
		data.age = data.html.age == "Today" && 9999999999 || data.html.age == "Yesterday" && 9999999998 || match && parseInt(match[1]) || 0
				
		if( data.html.age.match(/hour/) ) {
			data.age = data.age * 60
		} else if( data.html.age.match(/day/) ) {
			data.age = data.age * (60 * 24)
		} else if( data.html.age.match(/week/) ) {
			data.age = data.age * (60 * 24 * 7)
		}
		
		table_data.push(data)
	})
}

function setup_table() {
	if( !location.href.match("#(.+)") ) return
	scrape_table()

	// Setup anything we had saved through the url
	var jsdata = location.href.match("#(.+)")
	jsdata = jsdata ? jsdata[1] : ""
	
	var sort = jsdata.match("(.+):(0|1)")
	if( sort ) {
		sort_id = $("#" + sort[1]).length > 0 ? sort[1] :  sort_id
		sort_asc = parseInt(sort[2])
	}

	sort_table($("#" + sort_id), sort_asc || 0)
}

var previous_column = null
function sort_table(header, asc) {
	if( previous_column ) $("." + previous_column).removeClass("darkbg").removeClass("lightbg")
	previous_column = header.attr("id")
	
	if( asc ) {
		$("." + header.attr("id")).addClass("darkbg")
	} else {
		$("." + header.attr("id")).addClass("lightbg")
	}
	
	if( header.attr("id").match("character") ) {
		$("." + header.attr("id").replace("character", "charheader")).addClass(asc ? "darkbg" : "lightbg")
	}
	
	header.removeClass("darkbg").removeClass("lightbg")
	previous_column = header.attr("id")
	
	table_data.sort(function(a, b) {
		a_val = a[header.attr("id")]
		b_val = b[header.attr("id")]
		
		if( a_val == parseInt(a_val) || a_val == parseFloat(a_val) ) {
			return asc ? a_val - b_val : b_val - a_val
		} else if( a_val == b_val ) {
			if( a.name < b.name ) {
				return asc ? -1 : 1
			} else if( a.name > b.name ) {
				return asc ? 1 : -1
			} else {
				return 0
			}
		} else if( a_val < b_val ) {
			return asc ? -1 : 1
		} else if( a_val > b_val ) {
			return asc ? 1 : -1
		}
		
		return 0
	})
	
	update_table()
}

function header_clicked(event) {
	if( table_data.length == 0 ) {
		scrape_table()
	}
	
	$("#sortlist > .headerbg > .header").removeClass("selected")
	$("#sortlist th").removeClass("selected")
	$(this).addClass("selected")
	
	if( sort_id != this.id ) {
		sort_asc = 0
		sort_id = this.id
	} else if( sort_asc == 1 ) {
		sort_asc = 0
	} else {
		sort_asc = 1
	}
	
	sort_table($(this), sort_asc == 1)
	
	var url = location.href.match("(.+)#")
	url = url ? url[1] : location.href
	
	location.href = url + "#" + sort_id + ":" + sort_asc
}
$(document).ready(function() {
	$("#sortlist > .headerbg > .header").mouseenter(function(event) { $(this).addClass("highlight") })
	$("#sortlist > .headerbg > .header").mouseleave(function(event) { $(this).removeClass("highlight") })

	$("#sortlist th").mouseenter(function(event) { $(this).addClass("highlight") })
	$("#sortlist th").mouseleave(function(event) { $(this).removeClass("highlight") })

	$("#sortlist th").click(header_clicked)
	$("#sortlist > .headerbg > .header").click(header_clicked)
})

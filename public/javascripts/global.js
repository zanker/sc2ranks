function rename_character(character_id) {
	if( $("#new_name").length == 0 ) {
		var html = ""
		html += "<form onsubmit='check_battlenet(" + character_id + "); return false;' class='renameset'>"
		html += "<input type='text' id='new_name' value='New name' class='example'> <input type='submit' text='Go' id='new_name_submit'>"
		html += "<div style='clear: both; margin-bottom: 8px;'></div>"
		html += "<img src='/images/loading.gif' id='bnet_loading'>"
		html += "<span id='update_status'></span>"
		html += "</form>"
		
		$(".secondary").hide();
		$(html).appendTo(".misc-container")
		
		$("#new_name").focusin(function() { if( $(this).hasClass("example") ) $(this).val("").removeClass("example") })
		$("#new_name").focusout(function() { if( $(this).val() == "" ) $(this).val("New name").addClass("example") })
		
		$("#bnet_loading").hide();
	} else {
		if( $(".renameset").is(":visible") ) {
			$(".secondary").show()
			$(".renameset").hide()
		} else {
			$(".secondary").hide()
			$(".renameset").show()
		}
		return
	}
}

function rename_error(message) {
	$("#new_name").show();
	$("#new_name_submit").show();
	$("#bnet_loading").hide();
	$("#update_status").text(message);
	$("#update_status").addClass("red");
}

function check_battlenet(character_id) {
	name = $("#new_name").val()
	
	$("#new_name_submit").hide();
	$("#new_name").hide();
	$("#bnet_loading").show();
	$("#update_status").removeClass("red");
	$("#update_status").text("Checking if name exists...");
	
	$.ajax({
		type: "POST",
		url: "/rename/character",
		data: {character_id: character_id, name: name},
		dataType: "json",
		success: function(data, textStatus, xhr) {
			if( data.success ) {
				$("#update_status").addClass("green")
				$("#update_status").text("Renamed! Updating...");
				location.href = location.href.replace("#", "");
				return;
			}
			
			$("#update_status").addClass("red")
			switch( data.error ) {
				case "bad_name":
					rename_error("Invalid name entered, or no name.");
					break;
				case "no_character":
					rename_error("Renaming a character that does not exist.");
					break;
				case "no_rename":
					rename_error("You must enter the new name, not the old.");
					break;
				case "invalid":
					rename_error("Invalid name. Must be exact including case.");
					break;
				case "http":
					if( data.code == 404 ) {
						rename_error("Invalid name. Must be exact including case.");
					} else if( data.code == 500 ) {
						rename_error("Battle.net is down, please try again later.");
					} else {
						rename_error("Battle.net error: " + data.message + " (" + data.code + ")");
					}
					break;
				default:
					rename_error("Unknown error, please try again.");
					break;
			}
		},
		error: function(xhr, textStatus, errorThrown) {
			rename_error(xhr.statusText + " (" + xhr.status + ")");
		}
	});
}

function social_popup(link, title, height, width) {
	twitter = window.open($(link).attr("href"), title, "height=450,width=600")
	if( window.focus ) twitter.focus()
}

/*
function bookmark(id) {
	$.cookie("bm", ($.cookie("bm") || "").replace("," + id, "") + "," + id, { expires: 365 })
	location.href = location.href
}

function unbookmark(id) {
	$.cookie("bm", ($.cookie("bm") || "").replace("," + id, ""), { expires: 365 })
	location.href = location.href
}
*/

function select_patch_data(url) {
	if( url.match(/all$/) ) {
		url += "/0";
	}
	
	if( !url.match("\/$") ) {
		url += "/"
	}
	
	location.href = url + $("#patch_stats").val()
}

function redirect_to_page(form, url, per_page) {
	page = parseInt($(form).find("input").val()) - 1
	window.location = url.replace(/page/, page * per_page)
}

function relative_time(from) {
	var now = (new Date).getTime() / 1000
    var distance_in_minutes = Math.floor((now - from) / 60)
   	if( distance_in_minutes <= 0 ) return "<1 minute"
    if( distance_in_minutes == 1 ) return "1 minute ago"
    if( distance_in_minutes < 45 ) return distance_in_minutes + " minutes ago"
    if( distance_in_minutes < 90 ) return "1 hour ago"
    if( distance_in_minutes < 1440 ) return  Math.round( distance_in_minutes / 60) + " hours ago"
    if( distance_in_minutes < 2880 ) return "1 day ago"
    if( distance_in_minutes < 43200 ) return Math.round( distance_in_minutes / 1440) + " days ago"
    if( distance_in_minutes < 86400 ) return "1 month ago"
    if( distance_in_minutes < 525960 ) return Math.round( distance_in_minutes / 43200) + " months ago"
    if( distance_in_minutes < 1051199 ) return "1 year ago"
 
    return "over " + Math.floor( distance_in_minutes / 525960) + " years ago"
}

$(document).ready(function() {
	// Deal with the sub-type options
	var sub_type_text = "Points";
	$("#psearch_type").change(function() {
		var selected = $(this).val();
		var sub_selected = $("#psearch_sub_type").val();
		
		if( selected == "1t" || selected == "2t" || selected == "3t" || selected == "4t" ) {
			$("#psearch_sub_type").html("<option value='points'>Points</option><option value='wins'>Wins</option><option value='losses'>Losses</option><option value='division'>Division name</option>");
		} else if( selected == "achieve" ) {
			$("#psearch_sub_type").html("<option value='points'>Points</option>");
		}
		
		$("#psearch_sub_type").val(sub_selected);
	});
	
	$("#psearch_sub_type, #psearch_type").change(function() {
		sub_type_text = $("#psearch_sub_type").find("option:selected").text()
		if( $("#psearch_value").hasClass("example") ) {
			$("#psearch_value").val(sub_type_text);
		}
	});

	$("#psearch_value").focusin(function() { if( $(this).hasClass("example") ) $(this).val("").removeClass("example") })
	$("#psearch_value").focusout(function() { if( $(this).val() == "" ) $(this).val(sub_type_text).addClass("example") })
	
	if( $("#psearch_value").val() == "" || $("#psearch_value").val() == sub_type_text ) {
		$("#psearch_value").val(sub_type_text).addClass("example");
	}
	
	// Toggles with save
	$(".toggleclick").not(".dumbtoggle").click(function() {
		id = $(this).attr("id")

		if( $.cookie(id) ) {
			$(this).html("-")
			$(this).parent().parent().find("tr[class]").show()
			$.cookie(id, null)
		} else {
			$(this).html("+")
			$(this).parent().parent().find("tr[class]").hide()
			$.cookie(id, true)
		}
	})
	
	$(".toggleclick").not(".dumbtoggle").each(function(id, toggle) {
		id = $(this).attr("id")
		if( $.cookie(id) ) {
			$(this).html("+")
			$(this).parent().parent().find("tr[class]").hide()
		}
	})
	
	$(".toggleclick").mouseenter(function() { $(this).addClass("togglefocus") })
	$(".toggleclick").mouseleave(function() { $(this).removeClass("togglefocus") })
	
	// Toggle without save
	$(".toggleheader").click(function() {
		indicator = $(this).find(".toggleclick")
		
		if( $(indicator).html() == "+" ) {
			$(indicator).html("-")
			$(this).parent().parent().find("tr[class]").show()
		} else {
			$(indicator).html("+")
			$(this).parent().parent().find("tr[class]").hide()
		}
	})
		
	// Cache JS times
	var today = new Date
	var time_utc = Date.UTC(today.getUTCFullYear(), today.getUTCMonth(), today.getUTCDate(), today.getUTCHours(), today.getUTCMinutes(), today.getUTCSeconds()) / 1000
	
	$(".jstime").each(function(id, element) {
		element = $(element)
		var timestamp = parseInt(element.attr("class").match("([0-9]+)")[1])		
		var distance = Math.floor((time_utc - timestamp) / 60)
		if( distance <= 0 ) {
			element.html("<1 minute ago")
		} else if( distance == 1 ) {
			element.html("1 minute ago")
		} else if( distance < 60 ) {
			element.html(distance + " minutes ago")
		} else if( distance < 120 ) {
			element.html("1 hour ago")
		} else if( distance < 1440 ) {
			element.html(Math.round(distance / 60) + " hours ago")
		} else if( distance < 2880 ) {
			element.html("1 day ago")
		} else if( distance < 10080 ) {
			element.html(Math.round(distance / 1440) + " days ago")
		} else if( distance <= 20160 ) {
			element.html("1 week ago")
		} else {
			element.html(Math.round(distance / 10080) + " weeks ago")
		}
	})

	$(".shortjstime").each(function(id, element) {
		element = $(element)
		var timestamp = parseInt(element.attr("class").match("([0-9]+)")[1])		
		var distance = Math.floor((time_utc - timestamp) / 60)
		if( distance <= 0 ) {
			element.html("<1 min")
		} else if( distance == 1 ) {
			element.html("1 min")
		} else if( distance < 60 ) {
			element.html(distance + " mins")
		} else if( distance < 120 ) {
			element.html("1 hour")
		} else if( distance < 1440 ) {
			element.html(Math.round(distance / 60) + " hours")
		}
	})
	
	
	// Stat field enabler (evil code, needs to be cleaned up)
	$("#statfilter_type").change(function() {
		$("#f-stats > form > label").removeClass("disabled")
		$("#f-stats > form > select").attr("disabled", null)
		
		if( $(this).val() == "achievements" ) {
			$("#f-stats > form > label").addClass("disabled")
			$("#f-stats > form > select").attr("disabled", "disabled")

			$("#statfilter_type").attr("disabled", null)
			$("#f-stats > form > label.type").removeClass("disabled")
			
			$("#statfilter_region").attr("disabled", null)
			$(".statregion").removeClass("disabled")
		} else {
			if( $(this).val() == "name" ) {
				$("#statfilter_bracket").val("all")
				$("#statfilter_group").attr("disabled", "disabled")
				$(".statgroup").addClass("disabled")

				$(".statactivity").addClass("disabled")
				$("#statfilter_activity").attr("disabled", "disabled")
			}
			
			if( $(this).val() == "region" ) {
				$("#statfilter_region").attr("disabled", "disabled")
				$(".statregion").addClass("disabled")
			}
		
			if( $(this).val() == "race" ) {
				$("#statfilter_group").attr("disabled", "disabled")
				$(".statgroup").addClass("disabled")
			}

			if( $(this).val() == "race" || $(this).val() == "league" ) {
				$("#statfilter_league").attr("disabled", "disabled")
				$(".statleague").addClass("disabled")
			}
		}
	})
	
	$("#f-stats > form > label").removeClass("disabled")
	$("#f-stats > form > select").attr("disabled", null)

	if( $("#statfilter_type").val() == "achievements" ) {
		$("#f-stats > form > label").addClass("disabled")
		$("#f-stats > form > select").attr("disabled", "disabled")
		
		$("#statfilter_type").attr("disabled", null)
		$("#f-stats > form > label.type").removeClass("disabled")
		
		$("#statfilter_region").attr("disabled", null)
		$(".statregion").removeClass("disabled")
	} else {
		if( $("#statfilter_type").val() == "region" ) {
			$(".statregion").addClass("disabled")
			$("#statfilter_region").attr("disabled", "disabled")
		}
	
		if( $("#statfilter_type").val() == "race" || $("#statfilter_type").val() == "league" ) {
			$(".statleague").addClass("disabled")
			$("#statfilter_league").attr("disabled", "disabled")
		}
		
		if( $("#statfilter_type").val() == "name" ) {
			$("#statfilter_league").val("all")
			$(".statactivity").addClass("disabled")
			$("#statfilter_activity").attr("disabled", "disabled")
		}

		if( $("#statfilter_type").val() == "race" || $("#statfilter_type").val() == "name" ) {
			$("#statfilter_group").attr("disabled", "disabled")
			$(".statgroup").addClass("disabled")
		}
	}
	
	// Border highlighting
	$("input[type=text]").focusin(function() {
		$(this).addClass("focused")
	})
	$("input[type=text]").focusout(function() {
		$(this).removeClass("focused")
	})
	
	// Tab handling
	$("div.tabs > span, div.ptabs > span").mouseenter(function(event) {
		$(this).addClass("highlight")
	})
	$("div.tabs > span, div.ptabs > span").mouseleave(function(event) {
		$(this).removeClass("highlight")
	})
	
	$("div.tabs > span").click(function(event) {
		$("div.pages > div").addClass("invisible")
		$("div.tabs > span").removeClass("selected")

		$(this).addClass("selected")
		$("#f-" + this.id).removeClass("invisible")
	})

	// Achievement desc highlighter
	$(".deschighlight").mouseenter(function() { $(this).addClass("highlight") })
	$(".deschighlight").mouseleave(function() { $(this).removeClass("highlight") })
	
	// Dropdown handler
	$("div.menu > ul > .dropdown").mouseenter(function(event) {
		$(this).find(".arrow").removeClass("down").addClass("up")
		$(this).find(".text").addClass("highlight")
		$(this).find("ul").removeClass("invisible")
	})
	$("div.menu > ul > .dropdown").mouseleave(function(event) {
		$(this).find(".arrow").removeClass("up").addClass("down")
		$(this).find(".text").removeClass("highlight")
		$(this).find("ul").addClass("invisible")
	})
	
})

function load_default_search() {
	$(".csearch-form").each(function(id, form) {
		form = $(form)
		var is_default = form.find(".csearch-name").val() == "Character name" && form.find(".csearch-code").val() == "123"
		
		if( form.find(".csearch-name").val() == "" || is_default ) {
			form.find(".csearch-name").val("Character name").addClass("example")
		}

		if( form.find(".csearch-code").val() == "" || is_default ) {
			form.find(".csearch-code").val("123").addClass("example")
		}
	})
	
	$(".csearch-name").focusin(function() { if( $(this).hasClass("example") ) $(this).val("").removeClass("example") })
	$(".csearch-name").focusout(function() { if( $(this).val() == "" ) $(this).val("Character name").addClass("example") })

	$(".csearch-code").focusin(function() { if( $(this).hasClass("example") ) $(this).val("").removeClass("example") })
	$(".csearch-code").focusout(function() { if( $(this).val() == "" ) $(this).val("123").addClass("example") })

	$(".csearch-form").keydown(function(e) { if( e.keyCode == 13 ) { $(this).submit() } })
}
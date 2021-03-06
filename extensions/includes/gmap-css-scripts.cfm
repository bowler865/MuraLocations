<cfsilent><cfscript>
/**
* 
* This file is part of Muralocations TM
*
* Copyright 2010-2015 Stephen J. Withington, Jr.
* Licensed under the Apache License, Version v2.0
* http://www.apache.org/licenses/LICENSE-2.0
*
*/
</cfscript></cfsilent>
<cfoutput>
	<style type="text/css">
		h4.gmap-header-title { margin:1em 0 0 0; }

		/* categories */
			.gmap-category-filters { clear:both; display:block; }
			.gmap-category-filters .gmap-category-filter-wrapper { width:auto; float:left; padding:0.5em 0.5em 0.5em 0em; margin:0.5em 0.5em 0.5em 0em; }

		/* gmap */
			.gmap-wrapper .gmap-canvas .gmap-marker { visibility:hidden; }
			.gmap-wrapper .gmap-canvas { clear:both; display:block; width:#local.mapWidth#; height:#local.mapHeight# !important; }

		/* directions */
			.gmap-directions-form-wrapper, .gmap-directions { clear:both; display:block; padding:2em 0 1em 0; margin:auto; max-width:800px; }
			.gmap-directions { padding:0; }
			.gmap-directions img.adp-marker { width:1em; margin:0.5em; }
			.gmap-directions .adp-directions { width:100%; }
			input.req { border-color: red; }

		/* Bootstrap + GMap's infoWindow issue - https://github.com/twitter/bootstrap/issues/2410 */
			img[src*="gstatic.com/"], img[src*="googleapis.com/"] { max-width:99999px; }
	</style>

	<script type="text/javascript">
		/* <![CDATA[ */ 

			// polyfill for some()
			if (!Array.prototype.some) {
				Array.prototype.some = function(fun/*, thisArg*/) {
					'use strict';

					if (this == null) {
						throw new TypeError('Array.prototype.some called on null or undefined');
					}

					if (typeof fun !== 'function') {
						throw new TypeError();
					}

					var t = Object(this);
					var len = t.length >>> 0;
					var thisArg = arguments.length >= 2 ? arguments[1] : void 0;
					for (var i = 0; i < len; i++) {
						if (i in t && fun.call(thisArg, t[i], i, t)) {
							return true;
						}
					}

					return false;
				};
			}

			var findOne = function (haystack, arr) {
				return arr.some(function (v) {
					return haystack.indexOf(v) >= 0;
				});
			}

			var defaultFor = function(arg, val) {
				return typeof arg !== 'undefined' ? arg : val;
			}

			jQuery(document).ready(function($) {

				var infoWindow = new google.maps.InfoWindow();

				var render_map = function ($el) {
					var $markers = $el.find('.gmap-marker');
					var args = {
							center: new google.maps.LatLng(0, 0)
							, minZoom: 2
							, backgroundColor: '##ffffff'
							, mapTypeId: google.maps.MapTypeId.#UCase(arguments.mapType)#
							, scrollwheel: true
							, navigationControl: true
							, mapTypeControl: false
							, scaleControl: true
							, draggable: true
					};

					// Create map	        	
					var map = new google.maps.Map($el[0], args);
					
					// Add a markers reference
					map.markers = [];

					// Add markers
					$markers.each(function () {
							add_marker($(this), map);
					});

					center_map(map);

					return map;
				}
				
				var add_marker = function ($marker, map) {
					var latlng = new google.maps.LatLng($marker.attr('data-lat'), $marker.attr('data-lng'));
					var icon = null;

					var marker = new google.maps.Marker({
							position: latlng
							, animation: google.maps.Animation.DROP
							, map: map
							, filter: {
								categories: $marker.data('categories').toString()
							}
					});

					if ( $marker.html() ) {
						google.maps.event.addListener(marker, 'click'
							, (function(marker) {
								return function() {
									infoWindow.setOptions({
										content: $marker.children().html()
									});
									infoWindow.open(map, marker);
								}
							})(marker)
						);
					}

					// Add to array
					map.markers.push(marker);
				}

				var center_map = function (map, zoom) {
					var bounds = new google.maps.LatLngBounds();

					<cfif StructKeyExists(arguments, 'mapZoom') and mapZoom neq 'default'>
						zoom = defaultFor(zoom, #arguments.mapZoom#);
					</cfif>

					// Loop through all markers and create bounds
					$.each(map.markers, function (i, marker) {
							var latlng = new google.maps.LatLng(marker.position.lat(), marker.position.lng());
							bounds.extend(latlng);
					});
					map.fitBounds(bounds);

					if (typeof zoom !== 'undefined') {
						google.maps.event.addListenerOnce(map, 'bounds_changed', function(event) {
							this.setZoom(zoom);
						});
					}
				}

				var map = null;
				
				$('.gmap-canvas').each(function () {
						map = render_map($(this));
				});

				$('input.gmap-category-filter-option').on('click', function () {
					var categories = [];

					$(this).parent().toggleClass('gmap-category-highlight');

					$('input.gmap-category-filter-option:checked').each(function() {
						categories.push($(this).val());
					});
		
					$.each(map.markers, function () {
						var thisMarkerVisible = findOne(this.filter.categories, categories) ? true : false;
						this.setVisible(thisMarkerVisible);
					});

				});

				$(window).resize(function() {
					// resize the map to fit the window when being resized
					center_map(map, map.getZoom());
				});
				
				<cfif StructKeyExists(arguments, 'displayDirections') and YesNoFormat(arguments.displayDirections)>
					// GMap Directions -----------------------------------------
						$("form###local.formID#").submit(function() {
							var $start = $('##start-#local.formID#');
							var start = $start.val();
							var end = $('##end-#local.formID#').val();
							var mode = $('##mode-#local.formID#').val();

							if (start === '') {
								$start.focus().attr('placeholder', 'Required').addClass('req');
							} else {
								$start.removeClass('req');
								calcRoute(start, end, mode);
							}

							return false;
						});

						var dirSvc = new google.maps.DirectionsService();
						var dirDsp = new google.maps.DirectionsRenderer();
						var $dirPanel = $('###local.mapDirectionsID#');

						dirDsp.setMap(map);
						dirDsp.setPanel($dirPanel[0]);

						var calcRoute = function (start, end, mode) {
							mode = defaultFor(mode, 'DRIVING');

							var request = {
								origin: start
								, destination: end
								, travelMode: google.maps.DirectionsTravelMode[mode]
							};

							dirSvc.route(request, function(response, status) {
								if (status === google.maps.DirectionsStatus.OK) {
									dirDsp.setDirections(response);
								}
							});
						}
				</cfif>

			});

		/* ]]> */
	</script>
</cfoutput>
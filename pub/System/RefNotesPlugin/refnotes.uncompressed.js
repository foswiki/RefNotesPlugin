/*
 * refnotes plugin 
 *
 * Copyright (c) 2025 Michael Daum
 *
 * Licensed under the GPL licenses http://www.gnu.org/licenses/gpl.html
 *
 */

"use strict";
(function($) {

  // Create the defaults once
  var defaults = {
      delay:500,
      duration:200,
      showEffect:"fadeIn",
      hideEffect:"fadeOut",
      track:false,
      tooltipClass:'default',
      items: 'a',
      position: "top",
      arrow: true,
      theme: 'default',

      /* work around https://bugs.jqueryui.com/ticket/10689 */
      close: function () { 
	$(".ui-helper-hidden-accessible > *:not(:last)").remove(); 
      }
    },
    /*
    defaultPosition = {
      my: "left+15 top+15",
      at: "left bottom",
      collision: "flipfit flip"
    };
    */
    defaultPosition = {
      "my": "right bottom", 
      "at": "left-5 top-5",
      collision: "flipfit flip"
    };


  // The actual plugin constructor
  function RefLink(elem, opts) {
    var self = this;

    self.elem = $(elem);
    self.opts = $.extend({}, defaults, self.elem.data(), opts);

    self.opts.show = $.extend(self.opts.show, {
      effect: self.opts.showEffect,
      delay: self.opts.delay,
      duration:self.opts.duration
    });
    self.opts.hide = $.extend(self.opts.hide, {
      effect: self.opts.hideEffect,
      delay: self.opts.delay,
      duration:self.opts.duration
    });

    if (typeof(self.opts.theme) !== 'undefined') {
      self.opts.tooltipClass = self.opts.theme;
    }

    if (typeof(self.opts.position) === 'string') {
      switch(self.opts.position) {
        case "bottom":
          self.opts.position = {"my":"center top", "at":"center bottom+13"};
          self.opts.track = false;
          break;
        case "top":
          self.opts.position = {"my":"center bottom", "at":"center top-13"};
          self.opts.track = false;
          break;
        case "right":
          self.opts.position = {"my":"left middle", "at":"right+13 middle"};
          self.opts.track = false;
          break;
        case "left":
          self.opts.position = {"my":"right middle", "at":"left-13 middle"};
          self.opts.track = false;
          break;
        case "top left":
        case "left top":
          self.opts.position = {"my":"right bottom", "at":"left-5 top-5"};
          self.opts.track = false;
          opts.arrow = false;
          break;
        case "top right":
        case "right top":
          self.opts.position = {"my":"left bottom", "at":"right+5 top-5"};
          self.opts.track = false;
          opts.arrow = false;
          break;
        case "bottom left":
        case "left bottom":
          self.opts.position = {"my":"right top", "at":"left-5 bottom+5"};
          self.opts.track = false;
          opts.arrow = false;
          break;
        case "bottom right":
        case "right bottom":
          self.opts.position = {"my":"left top", "at":"right+5 bottom+5"};
          self.opts.track = false;
          opts.arrow = false;
          break;
        default:
          self.opts.position = $.extend({}, defaultPosition);
      }
    } 

    if (typeof(self.opts.position) === 'object') {
      self.opts.position.using = function(coords, feedback) {
          var $modal = $(this),
              horiz = feedback.horizontal,
              vert = feedback.vertical,
              className;


          /* map it to the correct position name */
          switch (vert) {
            case "bottom": vert = "top"; break;
            case "top": vert = "bottom"; break;
          }
          switch (horiz) {
            case "left": horiz = "right"; break;
            case "right": horiz = "left"; break;
          }

          className = "position-" + horiz + ' position-' + vert;

          $modal.removeClass(function (index, css) {
            return (css.match (/\position-\w+/g) || []).join(' ');
          });

          $modal.addClass(className);
          $modal.css(coords);
        };
    }

    self.opts.content = function() {
      if (self.content === undefined) {
        var selector = $(this).attr("href"),
          content = $(selector).clone();

        content.find("b").remove();
        self.content = content.html();
      }

      return self.content;
    }

    self.elem.tooltip(self.opts).on("tooltipopen", function(ev, ui) {
      if (self.opts.arrow) {
        ui.tooltip.prepend("<div class='ui-arrow'></div>");
      }
    });
  }

  $.fn.refLink = function (opts) {
    return this.each(function () {
      if (!$.data(this, "RefLink")) {
        $.data(this, "RefLink", new RefLink(this, opts));
      }
    });
  };

  // Enable declarative widget instanziation
  $(function() {
    $(".refLinkWithTooltip").livequery(function() {
      $(this).refLink();
    });
  });

})(jQuery);


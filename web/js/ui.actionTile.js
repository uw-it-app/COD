/*jslint nomen: true, regexp: true */
/*global $ */
(function () {
    'use strict';

    $.widget('ui.actionTile', {
        _init: function () {
            var defaultOptions = {active: false, cookie: false},
                _element = $(this.element);

            this.options = $.extend(defaultOptions, this.options);

            if (!this.options.title) {
                this.options.title = _element.attr('data-title');
            }

            _element.tile($.extend({}, this.options));

            this._connectControllerStuff();
        },

        _connectControllerStuff: function () {
            //RESTService setup
            //link submits to command that grabs data and sends to API
        },

        highlight: function () {
            $(this.element).addClass('highlight').tile('show').tile('lockOpen');
        },

        normal: function () {
            $(this.element).removeClass('highlight').tile('unlock');
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

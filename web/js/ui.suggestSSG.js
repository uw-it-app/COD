/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger*/
/*global badgerArray*/
(function () {
    'use strict';

    $.widget('ui.suggestSSG', {
        _init: function () {
            var defaultOptions = {
                    RESTErrorHandler: function (XMLHttpRequest, textStatus, errorThrown) {
                        logger.debug(errorThrown);
                    },
                    selectFirst: true,
                    select: function (event, ui) {
                        this.value = ui.item.value;
                        $(this).trigger('change');
                        return false;
                    },
                    source: function (request, response) {
                        var _this = this;
                        $.ajax({
                            url: $(this.element).data('url'),
                            dataType: "json",
                            data: {
                                q: request.term
                            },
                            error: _this.RESTErrorHandler,
                            success: function (data) {
                                data.Options.Option = badgerArray(data.Options.Option);
                                if (data.Options.Option.length === 0) {
                                    response([]);
                                    return;
                                }
                                response($.map(data.Options.Option, function (item) {
                                    return {
                                        label: item.Label,
                                        value: item.Value,
                                        id: item.id
                                    };
                                }));
                            }
                        });
                    }
                };

            this.options = $.extend(defaultOptions, this.options);

            this.element.autocomplete(this.options);
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

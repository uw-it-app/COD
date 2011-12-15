/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global RESTDataSource */
/*global badgerArray */
/*global COD */
/*global window */
(function () {
    'use strict';

    $.widget('ui.item', {
        _init: function () {
            this._connectControllerStuff();
            this.refreshData();
        },

        _connectControllerStuff: function () {
            COD.data.item = {Item: {}};
            COD.REST.item = new RESTDataSource(COD.dataSources.item, COD.RESTErrorHandler);
        },

        refreshData: function () {
            var _this = this;
            COD.REST.item.get(
                {Id: this.options.Id},
                function (data) {
                    data.Item.Escalations.Escalation = badgerArray(data.Item.Escalations.Escalation);
                    data.Item.Actions.Action = badgerArray(data.Item.Actions.Action);
                    data.Item.Events.Event = badgerArray(data.Item.Events.Event);
                    COD.data.item = data;
                    _this.jpopSync();
                },
                null
            );
        },

        jpopSync: function () {
            $('.item_bind').jpop(COD.data.item, {});
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

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
            this._pretty();
            this.refreshData();
        },

        _connectControllerStuff: function () {
            COD.data.item = {Item: {}};
            COD.REST.item = new RESTDataSource(COD.dataSources.item, COD.RESTErrorHandler);
        },
        
        _pretty: function() {
            $('title').text('COD Item');
            $('.tile_action').tile({title:"Actions"});
            $('.tile_event').tile({title:"Events"});
            $('.tile_escalate').tile({title:"Escalations"});
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
            $('title').text('COD: ('+COD.data.item.Item.Id+') '+COD.data.item.Item.Subject);
            $('.item_bind').jpop(COD.data.item, {});
            $('#item_container').show();
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

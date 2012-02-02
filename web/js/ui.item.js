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

        _pretty: function () {
            $('title').text('COD Item');
            $('.tile_action').tile({title: "Actions", nocookie: true});
            $('.tile_event').tile({title: "Events", nocookie: true});
            $('.tile_escalate').tile({title: "Escalations", nocookie: true});
            $('.tile_clear').tile({title: "Clear Alert", nocookie: true, close: true});
            $('.tile_reactivate').tile({title: "Reactivate Alert", nocookie: true, close: true});
            $('.tile_resolve').tile({title: "Resolve", nocookie: true, close: true});
            $('.tile_helptext').tile({title: "Work Helptext", nocookie: true, close: true});
            $('.tile_refnumber').tile({title: "Set Reference Number", nocookie: true, close: true});
            $('.tile_setnag').tile({title: "Set Nag Time", nocookie: true, close: true});
            $('.tile_nag').tile({title: "Nag", nocookie: true, close: true});
            $('.tile_message').tile({title: "Send message", nocookie: true, close: true});
            $('.tile_createesc').tile({title: "Create Escalation", nocookie: true, close: true});
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
            $('title').text('COD: (' + COD.data.item.Item.Id + ') ' + COD.data.item.Item.Subject);
            $('.item_bind').jpop(COD.data.item, {});
            $('#item_container').show();
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

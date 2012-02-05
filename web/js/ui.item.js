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
            $('.tile_action').tile({title: "Actions", cookie: false});
            $('.tile_times').tile({title: "Times", cookie: false});
            $('.tile_event').tile({title: "Events", cookie: false});
            $('.tile_escalate').tile({title: "Escalations", cookie: false});
            $('.action_tile').actionTile();
        },

        refreshData: function () {
            var _this = this;
            COD.REST.item.get(
                {Id: this.options.Id},
                function (data) {
                    if (data.Item.Escalations.Escalation === undefined) {
                        data.Item.Escalations = {Escalation: []};
                    } else {
                        data.Item.Escalations.Escalation = badgerArray(data.Item.Escalations.Escalation);
                    }
                    if (data.Item.Actions.Action === undefined) {
                        data.Item.Actions = {Actions: []};
                    } else {
                        data.Item.Actions.Action = badgerArray(data.Item.Actions.Action);
                    }
                    if (data.Item.Events === undefined) {
                        data.Item.Events = {Event: []};
                    } else {
                        data.Item.Events.Event = badgerArray(data.Item.Events.Event);
                    }
                    COD.data.item = data;
                    _this.jpopSync();
                },
                null
            );
        },

        jpopSync: function () {
            var Item = COD.data.item.Item;
            $('title').text('COD: (' + Item.Id + ') ' + Item.Subject);
            $('.item_bind').jpop(COD.data.item, {});
            $('.datetime').each(function () {
                var _content = $(this).text();
                if (_content === "") {
                    $(this).parent().hide();
                } else {
                    $(this).parent().show();
                }
            });
            $('.helpText').each(function () {
                var _content = $(this).text();
                $(this).attr({"href": _content});
                _content = _content.replace(/https?:\/\//, '').replace(/\.washington\.edu/, ': ').replace(/\/display\/monhelp\/component-/, '');
                $(this).text(_content);
            });
            if (Item.Times.Started) {
                if (Item.Times.Ended) {
                    $('#ActionClear').tile('hide');
                    $('#ActionReactivate').tile('show');
                } else {
                    $('#ActionClear').tile('show');
                    $('#ActionReactivate').tile('hide');
                }
            } else {
                $('#ActionClear').tile('hide');
                $('#ActionReactivate').tile('hide');
            }
            if (Item.Times.Resolved) {
                $('ActionNag').tile('hide');
                $('ActionSetNag').tile('hide');
            } else {
                $('ActionNag').tile('show');
                $('ActionSetNag').tile('show');
            }
            $('.prompted_action').tile('hide');
            $.each(Item.Actions.Action, function () {
                if (!this.Completed.At) {
                    $('#Action' + this.Type).actionTile('highlight');
                };
            });
            //if prompted for helptext $('#ActionHelpText').actionTile('highlight'); else hide
            //if prompted for nag $('#ActionNag').actionTile('highlight'); else hide
            //if prompted for phonecall $('#ActionPhone').actionTile('highlight'); else hide
            //if prompted for resolve $('#ActionResolve').actionTile('highlight'); else hide
            //if prompted for oncallgroup -- highlight create escalation
            //if prompted for clear...
            $('#item_container').show();
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

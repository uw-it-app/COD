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
            this.getData();
        },

        _connectControllerStuff: function () {
            var _this = this;
            COD.data.item = {Item: {}};
            COD.REST.item = new RESTDataSource(COD.dataSources.item, COD.RESTErrorHandler);
            $(document).on('click', 'a.actSetOwner', function () {
                var a = $(this),
                    e_id = a.next().val();
                $('#ActionSetOwner').actionTile('newData', {Action:{Type:"SetOwner",Data:{EscalationId:e_id}}}).actionTile('highlight');
                return false;
            });
            $(document).on('click', 'input[type="submit"]', function () {
                var s = $(this),
                    tile = s.parents('.action_tile'),
                    fields = $('#' + tile.attr('id') + ' input[type!="submit"], #'+tile.attr('id') + ' select, #'+tile.attr('id') + ' textarea'),
                    Item = {Id:COD.data.item.Item.Id,Do:{}};

                fields.each(function () {
                    var i = $(this);
                    Item.Do[i.attr('name')] = i.val();
                });
                Item.Do['Submit'] = s.val();
                COD.REST.item.put({Id: Item.Id}, {Item:Item}, $.proxy(_this._updateData, _this), null);
                tile.actionTile('normal').tile('close');
                $('.sync_clear').val('');
                return false;
            });
        },

        _pretty: function () {
            $('title').text('COD Item');
            $('.tile_action').tile({title: "Actions", cookie: false});
            $('.tile_times').tile({title: "Times", cookie: false});
            $('.tile_event').tile({title: "Events", cookie: false});
            $('.tile_escalate').tile({title: "Escalations", cookie: false});
            $('.action_tile').actionTile();
            COD.createLastUpdated();
        },

        _updateData: function(data) {
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
            this.jpopSync();
        },

        getData: function () {
            COD.REST.item.get({Id: this.options.Id}, $.proxy(this._updateData, this), null);
        },

        jpopSync: function () {
            var Item = COD.data.item.Item,
                oncalls = [],
                ocOptions = '<option value=""></option>';
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
            $.each(Item.Events.Event, function() {
                if (this.Contact && ($.inArray(this.Contact) === -1)) {
                    oncalls.push(this.Contact);
                }
                if (this.OncallPrimary && ($.inArray(this.OncallPrimary) === -1)) {
                    oncalls.push(this.OncallPrimary);
                }
                if (this.OncallAlternate && ($.inArray(this.OncallAlternate) === -1)) {
                    oncalls.push(this.OncallAlternate);
                }
            });
            $.each(oncalls, function () {
                ocOptions = ocOptions + '<option value="'+this+'">'+this+'</option>';
            });
            ocOptions = ocOptions + '<option value="duty_manager">DutyManager</option><option value="_">Custom</option>';
            $('#escalateTo').html(ocOptions);
            $('.helpText').each(function () {
                var _content = $(this).text();
                $(this).attr({"href": _content});
                _content = _content.replace(/https?:\/\//, '')
                                   .replace(/\.washington\.edu/, ': ')
                                   .replace(/\/display\/monhelp\/component-/, '');
                $(this).text(_content);
            });
            if (Item.Times.Closed) {
                $('#ActionClear').tile('hide');
                $('#ActionReactivate').tile('hide');
                $('#ActionNag').tile('hide');
                $('#ActionSetNag').tile('hide');
                $('#ActionEscalate').tile('hide');
            } else {
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
                    $('#ActionNag').tile('hide');
                    $('#ActionSetNag').tile('hide');
                } else {
                    $('#ActionNag').tile('show');
                    $('#ActionSetNag').tile('show');
                }
            }
            $('.prompted_action').tile('hide');
            $.each(Item.Actions.Action, function () {
                if (!this.Completed.At && (this.Successful === '')) {
                    $('#Action' + this.Type).actionTile('newData', {Action:this}).actionTile('highlight');
                };
            });
            $('.suggest').suggestSSG({RESTErrorHandler:COD.RESTErrorHandler});
            COD.rtLinker();
            COD.hmLinker();
            COD.updateLastUpdated();
            $('#item_container').show();
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

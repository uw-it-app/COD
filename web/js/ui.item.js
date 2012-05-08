/*global $ */
/*global logger */
/*global COD */
/*global window */
/*global document*/
(function () {
    'use strict';

    $.widget('ui.item', {
        _init: function () {
            this._connectControllerStuff();
            this._pretty();
            this.getData();
        },

        _connectControllerStuff: function () {
            var _this      = this;
            COD.data.item  = {Item: {}};
            COD.data.enums = null;
            COD.REST.item  = $.RESTDataSource(COD.dataSources.item, COD.RESTErrorHandler);
            COD.REST.enums = $.RESTDataSource(COD.dataSources.enums, COD.RESTErrorHandler);
            $(document).on('click', 'a.actSetOwner', function () {
                var a = $(this),
                    e_id = a.next().val();
                $('#ActionSetOwner').actionTile('newData', {Action: {Type: "SetOwner", Data: {EscalationId: e_id}}}).actionTile('highlight');
                return false;
            });
            $(document).on('click', 'input[type="submit"]', function () {
                var s = $(this),
                    tile = s.parents('.action_tile'),
                    fields = $('#' + tile.attr('id') + ' input[type!="submit"], #' + tile.attr('id') + ' select, #' + tile.attr('id') + ' textarea'),
                    Item = {Id: COD.data.item.Item.Id, Do: {}};

                fields.each(function () {
                    var i = $(this);
                    Item.Do[i.attr('name')] = i.val();
                });
                Item.Do.Submit = s.val();
                tile.actionTile('normal').tile('close');
                $('.sync_clear').val('').text('');
                if ($('#ActionEscalate').hasClass('highlight')) {
                    $('#ActionEscalate').actionTile('normal').tile('close');
                }
                COD.REST.item.put({Id: Item.Id}, {Item: Item}, $.proxy(_this._refreshData, _this), null);

                return false;
            });
            COD.createLastUpdated();
            $('#last-updated').on('click', function () {
                $.proxy(_this.getData(), _this);
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
        },

        _selectOptions: function (id, values) {
            var select = $(id).html('');
            $.each(values, function (key, value) {
                select.append('<option value="'+value+'">'+value+'</option>');
            });
        },

        _enumData: function (ajax) {
            var data;
            if (ajax === null) {
                return;
            }
            data = ajax[0];
            $.badgerfishArray(data, 'Enumerations.ITILTypes.ITILType');
            $.badgerfishArray(data, 'Enumerations.Severities.Severity');
            $.badgerfishArray(data, 'Enumerations.SupportModels.SupportModel');
            COD.data.enums = data;
            this._selectOptions('select#Item\\.ITILType', data.Enumerations.ITILTypes.ITILType);
            this._selectOptions('select#Item\\.Severity', data.Enumerations.Severities.Severity);
            this._selectOptions('select#Item\\.SupportModel', data.Enumerations.SupportModels.SupportModel);
        },

        _refreshData: function(data) {
            this._updateData([data]);
            this.jpopSync();
        },

        _updateData: function (ajax) {
            var data = ajax[0];
            $.badgerfishArray(data, 'Item.Escalations.Escalation');
            $.badgerfishArray(data, 'Item.Actions.Action');
            $.badgerfishArray(data, 'Item.Events.Event');
            COD.data.item = data;
        },

        _getEnumRequest: function () {
            if (COD.data.enums === null) {
                return COD.REST.enums.get({}, null, null);
            }
            return null;
        },

        getData: function () {
            var _this = this;
            $.when(
                this._getEnumRequest(),
                COD.REST.item.get({Id: this.options.Id}, null, null)
            ).done(function (ajaxEnum, ajaxItem) {
                _this._enumData(ajaxEnum);
                _this._updateData(ajaxItem);
                _this.jpopSync();
            });
        },

        jpopSync: function () {
            var Item = COD.data.item.Item,
                oncalls = [],
                ocOptions = '<option value=""></option>';
            $('title').text('COD: (' + Item.Id + ') ' + Item.Subject);
            $('.item_bind').jpop(COD.data.item, {});
            $('.hide_blank_row').each(function () {
                var _content = $(this).text();
                if (_content === "") {
                    $(this).parent().hide();
                } else {
                    $(this).parent().show();
                }
            });
            $.each(Item.Events.Event, function () {
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
                ocOptions = ocOptions + '<option value="' + this + '">' + this + '</option>';
            });
            ocOptions = ocOptions + '<option value="DutyManager">DutyManager</option><option value="_">Custom</option>';
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
                $('#ActionSetNag').tile('hide');
                if (COD.data.item.Item.Times.Nag) {
                    $('#ActionSetNag').tile('show');
                }
            }
            $('.prompted_action').tile('hide');
            if (COD.data.item.Item.ITILType === '(Notification)') {
                $('.action_tile').tile('hide');
                $('.tile_event').tile('hide');
            }
            $.each(Item.Actions.Action, function () {
                if (!this.Completed.At && (this.Successful === '')) {
                    $('#Action' + this.Type).actionTile('newData', {Action: this}).actionTile('highlight');
                }
            });
            $('.suggest').suggestSSG({RESTErrorHandler: COD.RESTErrorHandler});
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

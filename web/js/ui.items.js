/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global RESTDataSource */
/*global badgerArray */
/*global COD */
/*global window */
(function () {
    'use strict';

    $.widget('ui.items', {
        _init: function () {
            this._connectControllerStuff();
            
            this.refreshData();
        },

        _connectControllerStuff: function () {
            COD.data.items = {Items: {}};
            COD.createLastUpdated();
            COD.REST.items = new RESTDataSource(COD.dataSources.items, COD.RESTErrorHandler);
        },

        refreshData: function () {
            var _this = this;
            window.clearTimeout(COD.rid.items);
            COD.REST.items.get(
                {time: Number(new Date())},
                function (data) {
                    var count, i;
                    if (COD.data.items.Items.ModifiedAt === data.Items.ModifiedAt) {
                        COD.updateLastUpdated();
                        return;
                    }
                    data.Items.Item = badgerArray(data.Items.Item);
                    count = data.Items.Item.length;
                    for (i = 0; i < count; i += 1) {
                        data.Items.Item[i].Escalations.Escalation = badgerArray(data.Items.Item[i].Escalations.Escalation);
                    }
                    COD.data.items = data;
                    _this.jpopSync();
                },
                null
            );
            COD.rid.items = window.setTimeout(function () {_this.refreshData(); }, 30000);
        },

        jpopSync: function () {
            var _hm = true, _refno = true;
            $('.items_bind').jpop(COD.data.items, {});
            $('td.hm_issue').each(function(){ if ($(this).html()) { _hm = false;}});
            $('td.ref_no').each(function(){ if ($(this).html()) { _refno = false;}});
            if (_hm === true) {
                $('.hm_issue').hide();
            } else {
                $('.hm_issue').show();
            }
            if (_refno === true) {
                $('.ref_no').hide();
            } else {
                $('.ref_no').show();
            }
            COD.updateLastUpdated();
        },

        destroy: function () {
            $.Widget.prototype.destroy.apply(this, arguments); // default destroy
            $(this.element).empty();
        }

    });
}());

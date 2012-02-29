/*jslint nomen: true, regexp: true */
/*global $ */
/*global logger */
/*global location */
/*global moment*/
/*global document*/
/*global window*/
/*global escape*/
var COD = {},
    toolsAppName = {title: 'COD', href: '/cod/'};

(function () {
    'use strict';

    // Datasource locations
    COD.dataSources = {
        "items": "/daw/json/COD/v2/Items",
        "item": "/daw/json/COD/v2/Item"
    };

    // Namespace for JSON data
    COD.data = {};

    // RESTDatasource Error Handler
    COD.RESTErrorHandler = function (XHR, textStatus, errorThrown) {
        var data,
            msg = '';
        logger.debug(errorThrown + ': ' + XHR.responseText);
        if (XHR.status === 401) {
            window.setTimeout(function () {
                window.location = '/norns/?path=' + escape(window.location.pathname);
            }, 2000);
            window.toolsAlert('Login Required - Redirecting...');
        } else {
            data = JSON.parse(XHR.responseText);
            $.each(data.Errors, function (key, value) {
                msg = msg + key + ': ' + value[0] + "\n";
            });
            window.toolsAlert(msg);
        }
    };

    // REST DataSources
    COD.REST = {};

    // Refresh ID namespace
    COD.rid = {};

    COD.createLastUpdated = function () {
        $('#tools-app-title-bar-right').append('<div id="last-updated" style="display:none" class="clickme">Last Refresh: <span id="last-updated-time">____-__-__ __:__:__</span></div>');
    };

    COD.updateLastUpdated = function () {
        $('#last-updated-time').html(moment().format('YYYY-MM-DD HH:mm:ss'))
            .animate({backgroundColor: '#EDE'}, 500).delay(500).animate({backgroundColor: '#FFF'}, 500);
        $('#last-updated').show();
    };

    COD.rtLinker = function () {
        $('a.rtlink').each(function () {
            var value = $(this).text();
            $(this).attr({href: 'https://rt.cac.washington.edu/Ticket/Display.html?id=' + value});
        });
    };

    COD.hmLinker = function () {
        $('a.hmlink').each(function () {
            var value = $(this).text();
            $(this).attr({href: '/hm/view/issue/' + value});
        });
    };

    COD.linker = function () {
        $(document).on('click', 'a.rtlink, a.hmlink', function (e) {
            e.cancelBubble = true;
            window.open($(this).attr('href'));
            return false;
        });
    };
}());



<?php include('info.php'); ?>
<!DOCTYPE html>
<html lang="en">
    <meta charset="utf-8"/>
    <title>COD: Computer Operations Dashboard</title>
<?php include('css.php'); ?>
    <body>
        <div id="tools-container">
            <div id="tools-content">
<!-- Local HTML -->
<div id="itemsWrap" style="display:none">
<table id="itemsTable" class="full" >
    <thead>
        <tr>
            <th class="" style="display:none"></th>
            <th class="">State</th>
            <th class="">ITIL Type</th>
            <th class="">Subject</th>
            <th class="">RT Ticket</th>
            <th class="hm_issue">H&amp;M Issue</th>
            <th class="ref_no">Ref No</th>
            <th class="">Model</th>
            <th class="">Severity</th>
            <th class="">Escalations</th>
            <th class="">Modified</th>
        </tr>
    </thead>
    <tbody class="items_bind" id="Items:Item">
        <tr class="clickable item_click">
            <td class="items_bind item_id" id="Item.Id" style="display:none"></td>
            <td class="items_bind" id="Item.State"></td>
            <td class="items_bind" id="Item.ITILType"></td>
            <td class="items_bind" id="Item.Subject"></td>
            <td><a id="Item.RTTicket" class="items_bind rtlink" href='#' target='RTSuper'></a></td>
            <td class="hm_issue"><a id="Item.HMIssue" class="items_bind hmlink" href='#' target='HM'></a></td>
            <td class="items_bind ref_no" id="Item.ReferenceNumber"></td>
            <td class="items_bind" id="Item.SupportModel"></td>
            <td class="items_bind" id="Item.Severity"></td>
            <td>
                <table class="full">
                    <tr>
                        <th class="">Oncall</th>
                        <th class="">RT</th>
                        <th class="">H&amp;M</th>
                    </tr>
                <tbody class="items_bind" id="Item.Escalations:Escalation">
                    <tr>
                        <td class="items_bind" id="Escalation.OncallGroup"></td>
                        <td><a class="items_bind rtlink" id="Escalation.RTTicket" href="#" target="RTSub"></a></td>
                        <td><a class="items_bind hmlink" id="Escalation.HMIssue" href="#" target="HM"></a></td>
                    </tr>
                </tbody>
                </table>
            </td>
            <td class="items_bind" id="Item.Modified.At"></td>
        </tr>
    </tbody>
</table>
</div>
<!-- End Local HTML -->
            </div>
        <!-- end #tools-content -->
        </div>
        <!-- end #tools-container -->
<!-- Start Script block -->
<?php include('js.php'); ?>
        <script src="/.cod/js/ui.items.js"></script>
        <script>
            var toolsBreadcrumbs = [
                {title: 'SSG', href: '/'},
                {title: 'COD', href: '/.cod/'}
            ];
            $(document).ready( function() {
                $('#tools-app-name a').after('<span class="version">v<?php echo $version ?></span>');
                $('#itemsTable').items();
                // stylize all the buttons with jQueryUI
                $("button, input[type=image], input[type=submit], input[type=reset], input[type=button]").button();
            });
        </script>
<!-- End Script block -->
    </body>
</html>

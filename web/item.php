<?php include('info.php'); ?>
<!DOCTYPE html>
<html lang="en">
    <meta charset="utf-8"/>
    <title></title>
<?php include('css.php'); ?>
    <body>
        <div id="tools-container">
            <div id="tools-content">
<!-- Local HTML -->
<div id="item_container" style="display:none">
    <div id="item_header">
        <div class="tile_row">
            <div class="tile_block full">
                <div id="Item.Subject" class="item_bind full box" ></div>
                <div class="label"><span class="help">Subject</span></div>
            </div>
        </div>
        <div class="tile_row">
            <div class="tile_block">
                <div id="Item.State" class="item_bind short box"></div>
                <div class="label"><span class="help">State</span></div>
            </div>
            <div class="tile_block">
                <div class="short box">
                    <a id="Item.RTTicket" class="item_bind rtlink" href='#' target='RTSuper'></a>
                </div>
                <div class="label"><span class="help">RT Ticket</span></div>
            </div>
            <div class="tile_block">
                <div class="short box">
                    <a id="Item.HMIssue" class="item_bind hmlink" href='#' target='HM'></a>
                </div>
                <div class="label"><span class="help">H&amp;M Issue</span></div>
            </div>
            <div class="tile_block">
                <div id="Item.Stage" class="item_bind long box"></div>
                <div class="label"><span class="help">Stage</span></div>
            </div>
            <div class="tile_block">
                <div id="Item.SupportModel" class="item_bind xshort box"></div>
                <div class="label"><span class="help">Model</span></div>
            </div>
            <div class="tile_block">
                <div id="Item.Severity" class="item_bind xshort box"></div>
                <div class="label"><span class="help">Severity</span></div>
            </div>
            <div class="tile_block">
                <div id="Item.ITILType" class="item_bind short box"></div>
                <div class="label"><span class="help">ITIL Type</span></div>
            </div>
            <div class="tile_block">
                <div id="Item.ReferenceNumber" class="item_bind short box"></div>
                <div class="label"><span class="help">Ref#</span></div>
            </div>            
        </div>
    </div><!-- End item_header -->
    <div class="item_content">
        <div class="tile_row">
            <div class="tile_block tile_escalate">
                <table cellspacing="0" class="full item">
                    <thead>
                        <tr>
                            <th>State</th>
                            <th>RT Ticket</th>
                            <th>H&amp;M Issue</th>
                            <th>Oncall</th>
                            <th>Queue</th>
                            <th>Owner</th>
                            <th>Actions</th>
                        </tr>
                    </thead>
                    <tbody id="Item.Escalations:Escalation" class="item_bind">
                        <tr>
                            <td id="Esclation.State" class="item_bind"></td>
                            <td><a id="Esclation.RTTicket" class="item_bind rtlink" href='#' target='RTSub'></a></td>
                            <td>
                                <a id="Esclation.HMIssue" class="item_bind hmlink" href='#' target='HM'></a>
                                (<span id="Esclation.PageState" class="item_bind"></span>)
                            </td>
                            <td id="Esclation.OncallGroup" class="item_bind"></td>
                            <td id="Esclation.Queue" class="item_bind"></td>
                            <td id="Esclation.Owner" class="item_bind"></td>
                            <td>SetOwner | Message</td>
                        </tr>
                    </tbody>
                </table>
            </div>
        </div>
        <div class="tile_row">
            <div class="half tile_block">
                <div id="ActionsTile" class="tile_action">
                    <div id="ActionClose" class="action_tile tile_block prompted_action" data-title="Close">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Message</th>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="Close"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionPhoneCall" class="action_tile tile_block prompted_action" data-title="Phonecall">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">To</th>
                                <td>
                                    <span id="Action.FullName"></span> (<span id="Action.Name"></span>)
                                </td>
                            </tr>
                            <tr>
                                <th class="vertical">At</th>
                                <td id="Action.Data"></td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2">
                                    <textarea id="msgMessage" name="clearMessage" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="PhoneCall"/>
                                    <input id="SquawkId" type="hidden" name="SquawkId" value=""/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2"><input id="msg" type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionNag" class="action_tile tile_block prompted_action" data-title="Nag">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Message</th>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="Nag"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionHelpText" class="action_tile tile_block prompted_action" data-title="Work HelpText">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <td class="vertical">Work the helptext associated with the Event.</td>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="HelpText"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <input type="submit" value="Clear" class="actionSubmit half"/>
                                    <input type="submit" value="Fail" class="actionSubmit half"/>
                                </td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionClear" class="action_tile tile_block" data-title="Clear Alert">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Message</th>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="Clear"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionReactivate" class="action_tile tile_block" data-title="Reactivate Alert">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Message</th>
                            </tr>
                            <tr>
                                <td class="vertical">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="Reactivate"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>                        
                    </div>
                    <div id="ActionRefNumber" class="action_tile tile_block" data-title="Set Reference Number">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Reference#</th>
                                <td class="vertical">
                                    <input id="Item.ReferenceNumber" name="Value" class="item_bind short" />
                                    <input type="hidden" name="Type" value="RefNumber"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionSetNag" class="action_tile tile_block" data-title="Set Nag Time">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Nag in</th>
                                <td class="vertical">
                                    <input name="Number" class="short" value="30"/>
                                    <select name="Period"><option value="minutes">minutes</option><option value="hours">hours</option></select>
                                    <input type="hidden" name="Type" value="SetNag"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionMessage" class="action_tile tile_block" data-title="Send Message">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Type</th>
                                <td>
                                    <select name="MsgType"><option value="comment">comment</option><option value="reply">reply</option></select>
                                </td>
                            </tr>
                            <tr>
                                <th class="vertical">Send to Subs?</th>
                                <td>
                                    <select Name="ToSubs"><option value="yes">yes</option><option value="no">no</option></select>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2">
                                    <textarea name="Message" class="full" placeholder="Message"></textarea>
                                    <input type="hidden" name="Type" value="Message"/>
                                </td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                    <div id="ActionEscalate" class="action_tile tile_block"data-title="Create Escalation">
                        <table cellspacing="0" class="item full">
                            <tr>
                                <th class="vertical">Oncall</th>
                                <td>
                                    <select id="escalateTo" name="EscalateTo"><option value=""></option><option value="duty_manager">DutyManager</option><option value="_">Custom</option></select>
                                    <input name="Custom" value="" placeholder="Enter custom oncall" class="full suggest_oncall"/>
                                    <input type="hidden" name="Type" value="Escalate"/>
                                </td>
                            </tr>
                            <!--<tr>
                                <th class="vertical" colspan="2">Message</th>
                            </tr>-->
                            <tr>
                                <td class="vertical" colspan="2"><textarea name="Message" class="full" placeholder="Message"></textarea></td>
                            </tr>
                            <tr>
                                <td class="vertical" colspan="2"><input type="submit" value="Submit" class="actionSubmit full"/></td>
                            </tr>
                        </table>
                    </div>
                </div>
            </div>
            <div class="half tile_block">
                <div class="tile_times">
                    <table cellspacing="0" class="item full">
                        <tr>
                            <th class="vertical">Created</th>
                            <td id="Item.Created.At" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Event Started</th>
                            <td id="Item.Times.Started" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Event Ended</th>
                            <td id="Item.Times.Ended" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Escalation Started</th>
                            <td id="Item.Times.Escalated" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Escalation Resolved</th>
                            <td id="Item.Times.Resolved" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Closed</th>
                            <td id="Item.Times.Closed" class="vertical item_bind datetime"></td>
                        </tr>
                    </table>
                </div>
                <div id="Item.Events:Event" class="item_bind  tile_event">
                    <table cellspacing="0" class="item full">
                        <tr>
                            <th class="vertical">Host</th>
                            <td id="Event.Host" class="vertical item_bind"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Component</th>
                            <td id="Event.Component" class="vertical item_bind"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Started</th>
                            <td id="Event.Times.Start" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Ended</th>
                            <td id="Event.Times.End" class="vertical item_bind datetime"></td>
                        </tr>
                        <tr>
                            <th class="vertical">HelpText</th>
                            <td class="vertical"><a id="Event.HelpText" href="" target="HelpText" class="helpText item_bind"></a></td>
                        </tr>
                        <tr>
                            <th class="vertical">Message</th>
                            <td id="Event.Message" class="vertical item_bind"></td>
                        </tr>
                        <tr>
                            <th class="vertical">Detail</th>
                            <td id="Event.LongMessage" class="vertical item_bind"></textarea></td>
                        </tr>
                    </table>
                </div>
            </div>
        </div>
    </div><!-- End item_content -->
</div><!-- End item_container -->
<!-- End Local HTML -->
            </div>
        <!-- end #tools-content -->
        </div>
        <!-- end #tools-container -->
<!-- Start Script block -->
<?php include('js.php'); ?>
        <script src="/.cod/js/ui.item.js"></script>
        <script src="/.cod/js/ui.actionTile.js"></script>
        <script>
            var itemId, toolsBreadcrumbs, urlHash = JSON.parse('<?php echo json_encode(pathinfoToHash()) ?>');
            itemId = urlHash.Id;
            toolsBreadcrumbs = [
                    {title: 'SSG', href: '/'},
                    {title: 'COD', href: '/.cod/'},
                    {title: 'Item ' + itemId, href: '/.cod/item/Id/' + itemId}
            ];
            $(document).ready( function() {
                $('#item_container').item({Id: itemId});
                // stylize all the buttons with jQueryUI
                $("button, input[type=image], input[type=submit], input[type=reset], input[type=button]").button();
            });
        </script>
<!-- End Script block -->
    </body>
</html>

<%@ page contentType="text/html;charset=UTF-8" language="java"%>
<%@ taglib prefix="c" uri="http://java.sun.com/jsp/jstl/core"%>
<%@ taglib prefix="fmt" uri="http://java.sun.com/jsp/jstl/fmt"%>
<%@ taglib prefix="shiro" uri="http://shiro.apache.org/tags"%>

<c:set var="ctx" value="${pageContext.request.contextPath}" />
<!DOCTYPE html>
<html lang="zh-CN">
<head>
<title>-IM聊天</title>
<c:set var="ctx" value="${pageContext.request.contextPath}" scope="application" />
<link href="<c:url value='/static/jquery/themes/base/jquery-ui.min.css?${version_css}'/>" rel="stylesheet" type="text/css" />

<script type="text/javascript" src="<c:url value='/static/js/JSJaC.js.js?${version_js}'/>"></script>

<script type="text/javascript">
  var oDbg, con;

  // <![CDATA[
  function handleIQ(oIQ) {
    document.getElementById('iResp').innerHTML += "<div class='msg'>IN (raw): " + oIQ.xml().htmlEnc() + '</div>';
    document.getElementById('iResp').lastChild.scrollIntoView();
    con.send(oIQ.errorReply(ERR_FEATURE_NOT_IMPLEMENTED));
  }

  function handleMessage(oJSJaCPacket) {
    var html = '';
    html += '<div class="msg"><b>Received Message from ' + oJSJaCPacket.getFromJID() + ':</b><br/>';
    html += oJSJaCPacket.getBody().htmlEnc() + '</div>';
    document.getElementById('iResp').innerHTML += html;
    document.getElementById('iResp').lastChild.scrollIntoView();
  }

  function handlePresence(oJSJaCPacket) {
    var html = '<div class="msg">';
    if (!oJSJaCPacket.getType() && !oJSJaCPacket.getShow())
      html += '<b>' + oJSJaCPacket.getFromJID() + ' has become available.</b>';
    else {
      html += '<b>' + oJSJaCPacket.getFromJID() + ' has set his presence to ';
      if (oJSJaCPacket.getType())
        html += oJSJaCPacket.getType() + '.</b>';
      else
        html += oJSJaCPacket.getShow() + '.</b>';
      if (oJSJaCPacket.getStatus()) html += ' (' + oJSJaCPacket.getStatus().htmlEnc() + ')';
    }
    html += '</div>';

    document.getElementById('iResp').innerHTML += html;
    document.getElementById('iResp').lastChild.scrollIntoView();
  }

  function handleError(e) {
    document.getElementById('err').innerHTML = "An error occured:<br />" + ("Code: " + e.getAttribute('code') + "\nType: " + e.getAttribute('type') + "\nCondition: " + e.firstChild.nodeName).htmlEnc();
    document.getElementById('login_pane').style.display = '';
    document.getElementById('sendmsg_pane').style.display = 'none';

    if (con.connected()) con.disconnect();
  }

  function handleStatusChanged(status) {
    oDbg.log("status changed: " + status);
  }

  function handleConnected() {
    document.getElementById('login_pane').style.display = 'none';
    document.getElementById('sendmsg_pane').style.display = '';
    document.getElementById('err').innerHTML = '';

    con.send(new JSJaCPresence());
  }

  function handleDisconnected() {
    document.getElementById('login_pane').style.display = '';
    document.getElementById('sendmsg_pane').style.display = 'none';
  }

  function handleIqVersion(iq) {
    con.send(iq.reply([iq.buildNode('name', 'jsjac simpleclient'), iq.buildNode('version', JSJaC.Version), iq.buildNode('os', navigator.userAgent)]));
    return true;
  }

  function handleIqTime(iq) {
    var now = new Date();
    con.send(iq.reply([iq.buildNode('display', now.toLocaleString()), iq.buildNode('utc', now.jabberDate()), iq.buildNode('tz', now.toLocaleString().substring(now.toLocaleString().lastIndexOf(' ') + 1))]));
    return true;
  }

  function doLogin(oForm) {
    var server = oForm.server.value, oArgs = new Object();

    oDbg = new JSJaCConsoleLogger(3);
    document.getElementById('err').innerHTML = '';
    // reset

    try {

      if (window.location.protocol !== "https:") {
        httpbase = 'http://' + server + ':5280/http-bind/';
      } else {
        httpbase = 'https://' + server + ':5281/http-bind/';
      }

      // set up the connection
      con = new JSJaCHttpBindingConnection({
        oDbg: oDbg,
        httpbase: httpbase,
        timerval: 500
      });

      setupCon(con);

      // setup args for connect method
      oArgs.domain = oForm.domain.value;
      oArgs.username = oForm.username.value;
      oArgs.resource = 'jsjac_simpleclient';
      oArgs.pass = oForm.password.value;
      oArgs.register = oForm.register.checked;
      con.connect(oArgs);
    } catch (e) {
      document.getElementById('err').innerHTML = e.toString();
    } finally {
      return false;
    }
  }

  function setupCon(oCon) {
    oCon.registerHandler('message', handleMessage);
    oCon.registerHandler('presence', handlePresence);
    oCon.registerHandler('iq', handleIQ);
    oCon.registerHandler('onconnect', handleConnected);
    oCon.registerHandler('onerror', handleError);
    oCon.registerHandler('status_changed', handleStatusChanged);
    oCon.registerHandler('ondisconnect', handleDisconnected);

    oCon.registerIQGet('query', NS_VERSION, handleIqVersion);
    oCon.registerIQGet('query', NS_TIME, handleIqTime);
  }

  function sendMsg(oForm) {
    if (oForm.msg.value == '' || oForm.sendTo.value == '') return false;

    if (oForm.sendTo.value.indexOf('@') == -1) oForm.sendTo.value += '@' + con.domain;

    try {
      var oMsg = new JSJaCMessage();
      oMsg.setTo(new JSJaCJID(oForm.sendTo.value));
      oMsg.setBody(oForm.msg.value);
      con.send(oMsg);

      oForm.msg.value = '';

      return false;
    } catch (e) {
      html = "<div class='msg error''>Error: " + e.message + "</div>";
      document.getElementById('iResp').innerHTML += html;
      document.getElementById('iResp').lastChild.scrollIntoView();
      return false;
    }
  }

  function quit() {
    var p = new JSJaCPresence();
    p.setType("unavailable");
    con.send(p);
    con.disconnect();

    document.getElementById('login_pane').style.display = '';
    document.getElementById('sendmsg_pane').style.display = 'none';
  }

  onunload = function() {
    if (typeof con != 'undefined' && con && con.connected()) {
      // save backend type
      if (con._hold)// must be binding
        (new JSJaCCookie('btype', 'binding')).write();
      else
        (new JSJaCCookie('btype', 'polling')).write();
      if (con.suspend) {
        con.suspend();
      }
    }
  };

  // ]]>
</script>
<style type="text/css">
/*<![CDATA[*/

h2 {
	border-bottom: 1px solid grey;
}

input {
	border: 1px solid grey;
}

#iResp {
	width: 420px;
	height: 260px;
	overflow: auto;
	border: 2px dashed grey;
	padding: 4px;
}

#msgArea {
	width: 420px;
	height: 45px;
	padding: 4px;
	margin: 0;
	border: 2px dashed grey;
}

.spaced {
	margin-bottom: 4px;
}

.msg {
	border-bottom: 1px solid black;
}

.error {
	font-weight: bold;
	color: red;
}
/*]]>*/
</style>
</head>

<body>
	<h1>
		<a href="#" onclick="location.reload();">JSJaC Simple Client</a>
	</h1>

	<div id="err"></div>

	<div id="login_pane">
		<h2>Login</h2>
		<form name="loginForm" onSubmit="return doLogin(this);" action="#">
			<table>
				<tr>
					<th><label for="server">Jabber Server</label></th>
					<td><input type="text" name="server" id="server" tabindex="3" value="jabber-example.org" /></td>
				</tr>
				<tr>
					<td colspan="2"><small>(this probably won't be user editable in your real world application)</small></td>
				</tr>
				<tr>
					<th colspan="2">
						<hr noshade size="1" />
					</th>
				</tr>
				<tr>
					<th><label for="domain">Jabber Server Domain Name</label></th>
					<td><input type="text" name="domain" id="domain" tabindex="4" value="jabber-example.org" /></td>
				</tr>
				<tr>
					<th><label for="username">Username</label></th>
					<td><input type="text" name="username" id="username" tabindex="5" /></td>
				</tr>
				<tr>
					<th><label for="password">Password</label></th>
					<td><input type="password" name="password" id="password" tabindex="6" /></td>
				</tr>
				<tr>
					<th></th>
					<td><input type="checkbox" name="register" id="register_checkbox" /> <label for="register_checkbox">Register new account</label></td>
				</tr>
				<tr>
					<td>&nbsp;</td>
					<td><input type="submit" value="Login" tabindex="7"></td>
				</tr>
			</table>
		</form>
	</div>

	<div id="sendmsg_pane" style="display: none;">
		<h2>Incoming:</h2>
		<div id="iResp"></div>
		<h2>Send Message</h2>
		<form name="sendForm" onSubmit="return sendMsg(this);" action="#">
			<div class="spaced">
				<b>To:</b> <input type="text" name="sendTo" tabindex="1">
			</div>
			<div class="spaced">
				<textarea name="msg" id='msgArea' rows="3" cols="80" tabindex="2"></textarea>
			</div>
			<div class="spaced">
				<input type="submit" value="Send" tabindex="3"> * <input type="button" value="Quit" tabindex="4" onclick="return quit();">
			</div>
		</form>
	</div>
</body>
</html>

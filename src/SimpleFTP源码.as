package  {
  import flash.net.Socket;
  import flash.events.*;
  import flash.utils.getTimer;

  public class SimpleFTP {
    public static function putFile(host:String, user:String, pass:String, 
                                   path:String, contents:String,
                                   listener:Function) {
      var s:SimpleFTP = new SimpleFTP(host, user, pass);
      s.putFile(path, contents, listener);
    }
/*下载文件方法
//建立连接  var s:SimpleFTP = new SimpleFTP(host, user, pass);
      s.getFile(path, listener);
*/
   public static function getFile(host:String, user:String, pass:String,
                                   path:String, listener:Function) {
      var s:SimpleFTP = new SimpleFTP(host, user, pass);
      s.getFile(path, listener);
    }

    private var host:String,user:String,pass:String;//ftp信息
    private var ctrlSocket:Socket = new Socket();//控制传输连接
    private var dataSocket:Socket = new Socket();//数据传输连接
    private var dataIP:String;//IP
    private var dataPort:int;//端口
    private var path:String, contents:String;
    private var listener:Function = null;
    private var step:int;
    private var put:Boolean;
    private var sa:Array;
///////////////////////////////////////////////////////////
    public function SimpleFTP(host:String, user:String, pass:String) {
      this.host = host;
      this.user = user;
      this.pass = pass;
      ctrlSocket.addEventListener(IOErrorEvent.IO_ERROR, error);
      ctrlSocket.addEventListener(SecurityErrorEvent.SECURITY_ERROR, error);
    }
/////////////////////////////////////////////////////////
    private function putFile(path:String, contents:String,
                             listener:Function):void {
      this.path = path;
      this.contents = contents;
      this.listener = listener;
      step = 0;//0检查连接状态
      put = true;
      ctrlSocket.addEventListener(ProgressEvent.SOCKET_DATA, session);
      ctrlSocket.connect(host, 21);
    }

    private function getFile(path:String, listener:Function):void {
      this.path = path;
      this.contents = contents;
      this.listener = listener;
      step = 0;//0检查连接状态
      put = false;
      ctrlSocket.addEventListener(ProgressEvent.SOCKET_DATA, session);
      ctrlSocket.connect(host, 21);
    }

    private function write(mes:String):void {
      ctrlSocket.writeUTFBytes(mes + "\r\n");
      ctrlSocket.flush();
    }
    
    private function response(res:String, contents:String = null):void {
      step = 11;//11的时候什么也不做
      if (put)
        listener(res);
      else
        listener(res, contents);//在对应位置输出提示和内容
      write("QUIT");
    }
    
    private function error(event:Event):void {
      if (put)
        listener(event.toString());//输出错误
      else
        listener(event.toString(), null);//输出错误信息
    }

    private function session(event:ProgressEvent):void {
      var res:String = ctrlSocket.readUTFBytes(ctrlSocket.bytesAvailable);//读取ftp服务端控制命令响应
      var st:String = res.substr(0, 3);
      trace(res);
 response(res);
      switch (step) {
      case 0:
        if (st == "220") {
          step++;//220打开连接之后请求用户名  把step增到1
          write("USER " + user);//输入用户名ftp控制命令
        } else
          response(res);//输出响应 并退出
        break;
      case 1:
        if (st == "331") {
          step++;//输入用户名之后331要求密码 把step增到2
          write("PASS " + pass);
        } else
          response(res);//输出响应 并退出
        break;
      case 2:
        if (st == "230") {//230成功连接服务器
          if (put)
            step = 3;//如果是上传调到step3
          else
            step = 4;//如果不是上传调到step4
          write("TYPE I");//数据类型（A=ASCII，E=EBCDIC，I=binary）
        } else
          response(res);//输出响应 并退出
        break;
      case 3:
        if (st == "200") {
          write("DELE " + path);//先删除服务器上的指定文件
          step++;
        } else
          response(res);//输出响应 并退出
        break;
      case 4:
        write("PASV");//请求服务器等待数据连接
        if (put)
          step = 5;//上传类型跳到5
        else
          step = 8;//下载的跳到8
        break;
      case 5://上传的跳到5
        if (st == "227") {
			//227进入被动模式
          step++;
          sa = res.substring(res.indexOf("(") + 1, res.indexOf(")")).split(",");
          dataIP = sa[0] + "." + sa[1] + "." + sa[2] + "." + sa[3];
          dataPort = parseInt(sa[4]) * 256 + parseInt(sa[5]);//获取响应服务器的数据传输连接的IP和端口
		  
		  
          write("STOR " + path);//储存（复制）文件到服务器上
          dataSocket.connect(dataIP, dataPort);
        } else
          response(res);//输出响应 并退出
        break;
      case 6:
        if (st == "125") {//打开数据连接，开始传输
          step++;
          dataSocket.writeUTFBytes(contents);
          dataSocket.flush();
          dataSocket.close();
        } else if(st=="150"){
		trace(st);
		 dataSocket.flush();
          dataSocket.close();
		}else {
          dataSocket.close();
          response(res);
        }
        break;
      case 7:
        response(res); // regardless if the res is "226" or not.
        break;
      case 8://下载的跳到8
        if (st == "227") {//227进入被动模式
          step++;
          sa = res.substring(res.indexOf("(") + 1, res.indexOf(")")).split(",");
                  dataIP = sa[0] + "." + sa[1] + "." + sa[2] + "." + sa[3];
                  dataPort = parseInt(sa[4]) * 256 + parseInt(sa[5]);//获取响应服务器的数据传输连接的IP和端口
          contents = "";
          dataSocket.addEventListener(ProgressEvent.SOCKET_DATA,
            function (event:ProgressEvent):void {
              contents += dataSocket.readUTFBytes(dataSocket.bytesAvailable);
            });
          dataSocket.connect(dataIP, dataPort);
          write("RETR " + path);//从服务器上找回（复制）文件
        } else
          response(res);
        break;
      case 9:
        if (st == "125")//打开数据连接，开始传输
          step++;
        else {
          dataSocket.close();
          response(res);
        }
        break;
      case 10:
        if (st == "226") // succeeded结束数据连接
          response(res, contents);
        else
          response(res);
        break;
      case 11:
        break;
      }
    }
  } 
}

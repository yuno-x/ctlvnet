# ctlvnet
本ツール群はLinux(Ubuntuを想定しています)で仮想ネットワークを構築するためのものです。

## 初期設定
仮想ノードを作成するためにdockerを設定します。所要時間は10-20分です。  
    $ ./mkimage node

仮想ノードはエンドポイントデバイスやルータとして使うことができます。

## 使い方
構築する仮想ネットワークによって使用するツールが異なります。  
以下はツールの使い方の説明に焦点を当てているため、その他コマンドの仕様などに関しては正確な説明に努めていますが、それを保証することはありません。


### ペアインタフェースの作成
仮想ネットワークでは、常にインタフェースの対向にもう一つのインタフェースが存在します。  
ip linkコマンドで仮想インタフェースを作成すると、このコマンドを実行したホストの仮想ネットワーク(名前)空間に2つのペアの仮想インタフェースを作成します。  
この技術を用いて、実ホスト(Real Host: 略 RH)の仮想ネットワーク空間にペアの仮想インタフェースを追加します。  

    $ ./ctl2net.sh connect - - - -

次の図のようなネットワークが構成されます。

![peer](https://github.com/yuno-x/ctlvnet/raw/img/node.png)

試しに以下のコマンドを実行してみてください。

    $ ip address

おそらく veth0, veth1 のペアのインタフェースが生成されていると思います。  
片方のインタフェースから dhclient コマンドでパケットを送って、もう片方のインタフェースで tcpdump コマンドを実行してパケットをキャプチャしてみるとパケットが送信できていることを確認することができます。  
ただし、IPアドレスが振られていません。  
次はIPアドレスを割り振ってみましょう。

    $ sudo ip address add 172.18.100.1/24 dev veth0
    $ sudo ip address add 172.18.100.2/24 dev veth1

IPアドレスが割り振られました。しかし、pingコマンドなどで疎通を確認してみても通信ができません。

    $ ping -I veth0 172.18.100.2
    ^C

ここで ARP テーブルを見てみましょう。

    $ ip neigh
    ~
    172.18.100.2 dev veth0  FAILED
    ~

と表示されるはずです。  
理由ははっきりとは分かりませんが(ループ防止？)、リプライが帰って来ないのは退屈です。  
次は仮想ノードを作成して疎通を確認してみましょう。  

その前にインタフェースを削除しましょう。

    $ sudo ip link del veth0

実ホストではipコマンドを用いて手動でインタフェースを削除する必要があります。  
仮想インタフェースは対になっていますので、対向のインタフェースであるveth1も削除されます。

### 仮想ノードの作成とリンクの作成
以下のコマンドで仮想ネットワークにノードを作成し、実ホストと接続してください。

    $ ./mkcontainer.sh node node1
    $ ./ctl2net.sh node1 172.18.100.101/24 - 172.18.100.100/24

ここでpingコマンドを実行してみると仮想ノードとパケットをやりとりすることができることがわかります。

    $ ping 172.18.100.101
    $ sudo docker exec -it node1 172.18.100.100

当然、ターミナルを2つ用意し、同時にpingパケットを送ることも可能です。  
以下では実ホストでネットワーク系のコマンドを打つときのプロンプトとして "RH$ ", node1のプロンプトとして "node1# "を使用しています。

    [Real Host]
    RH$ ping 172.18.100.101

    [node1]
    $ sudo docker exec -it node1 bash
    node1# ping 172.18.100.100

またノード同士を接続することもできます。

    $ ./mkcontainer.sh node node2
    $ ./ctl2ctl.sh connect node1 172.18.0.1/24 node2 172.18.0.2/24

    [node1]
    node1# ping 172.18.0.2

    [node2]
    node2# ping 172.18.0.1

![node](https://github.com/yuno-x/ctlvnet/raw/img/node.png)

どちらもデフォルトでapache2とcurlがインストールされているので、curlでapache2のデフォルトページをダウンロードすることも可能です。  
今回、node1とnode2の2つのホストをデータリンクさせましたが、3つ以上のホストをデータリンクさせることも可能です。  
これを実現するには仮想ブリッジを作成すればよい。Linuxの仮想ブリッジはラーニングスイッチとして作成され、MACアドレス-物理ポートの対応テーブル、いわゆるMACテーブルを参照してパケット(正確にはフレーム)をスイッチングします。  
次に仮想ブリッジを利用したネットワークを構築します。  
その前に node1, node2 を削除します。

    $ ./rmcontainer.sh node1 node2

実ホストRHとnode1はリンクされていましたが、node1削除と同時にnode1のインタフェースが削除されたので、実ホスト側の対向のインタフェースも同時に削除されます。


### L2ネットワーク構築
まずはnode1, node2, node3を作成します。

    $ ./mkcontainer node node1 node2 node3

仮想ブリッジbr0を作成後、node1, node2, node3の3つのノードを接続してみます。  

    $ ./ctl2net.sh setup br0 node1 172.18.0.1/24 node2 172.18.0.2/24 node3 172.18.0.3/24

上記のコマンドは以下のコマンドとほぼ同様の効果を示しています。  

    $ sudo ip link add br0 type bridge
    $ sudo ip link set br0 up
    $ ./ctl2net.sh connect br0 - node1 172.18.0.1/24
    $ ./ctl2net.sh connect br0 - node2 172.18.0.2/24
    $ ./ctl2net.sh connect br0 - node3 172.18.0.3/24

これによってnode1, node2, node3は相互にパケットを送受信できるようになりました。  
試しにnode1からnode2, node3へpingを送ってみます。  

    [node1]
    node1# ping 172.18.0.2
    ^C
    node1# ping 172.18.0.3
    ^C

疎通を確認することができるはずです。  

![switch](https://github.com/yuno-x/ctlvnet/raw/img/switch.png)

ちなみに仮想ブリッジは仮想インタフェースの一種として作成されます。  
つまり仮想ブリッジインタフェースを作成したホストは仮想ブリッジとなります。  
ブリッジの機能によってはIPパケットなどのL3フレームを送信することがあり
その場合ブリッジ自身にIPアドレスが割り振られていることになります。  
例えばブリッジを制御するためにブリッジへのSSHリモートアクセスを許可している場合、
ブリッジに割り振られたIPアドレスを指定してSSH接続します。  
そのためにブリッジはインタフェースとして作成されるといえるかもしれません。  
以下はスイッチbr0にIPアドレスを割り振って、node1からの疎通を確認しています。

    $ sudo ip address add 172.18.0.100/24 dev br0

    [node1]
    node1# ping 172.18.0.100
    ^C

疎通を確認できるはずです。
当然、仮想スイッチ(インタフェース)は同一ホストに複数作成することも可能です。

また、スイッチ同士を接続することも可能です。

    $ ./ctl2net.sh setup br1 node4 172.18.0.4/24 node5 172.18.0.5/24
    $ ./ctl2net.sh connect br0 - br1 -

    [node1]
    node1# ping 172.18.0.5
    ^C

これでブリッジbr0, br1を経由したnode1とnode5のパケット転送を行えたことを確認できました。  
ブリッジbr0のMACアドレステーブルは以下のコマンドで確認できます。

$ bridge fdb show br br0 | grep -vw "permanent"

もし、何も表示されなかったり、表示結果が少ないようならpingなどでパケットを送信してみてください。  
MACアドレステーブルにブリッジに埋め込まれているインタフェースとその対向のMACアドレスの関係が記録されていることが分かります。
このテーブルによってユニキャストへのパケットをセグメント内でブロードキャストせずに送ることができ、帯域を節約することができます。

さて、次はルーティングに触れますが、その前に作成したノードを削除しましょう。

    $ ./rmcontainer node1 node2 node3 node4 node5
    $ ./ctl2net delete br0 br1

以上で作成した環境は削除されたはずです。


### L3ネットワーク構築（スタティックルーティング）
次はL3ネットワークを構築するためにルータとネットワークセグメントが異なる2つのノードを作成します。  
そしてルータに2つのノードを接続し、IPアドレスを付与します。

    $ ./mkcontainer.sh node rt nodeA nodeB
    $ ./ctl2net.sh connect rt 172.18.0.254/24 nodeA 172.18.0.1/24
    $ ./ctl2net.sh connect rt 10.0.0.254/24 nodeB 10.0.0.1/24

さて、ではnodeAからnodeBへパケットを送ってみましょう。

    [nodeA]
    nodeA# ping 10.0.0.1
    ping: connect: Network is unreachable

上記のように送れないはずです。  
それはnodeAにnodeBへのルート情報を設定していないからです。  
試しにルーティングテーブルを確認してみましょう。  

    [nodeA]
    nodeA# ip route
    172.18.0.0/24 dev veth0 proto kernel scope link src 172.18.0.1

172.18.0.0/24 はルートの目的地となるネットワークセグメントです。  
dev veth0 はインタフェースveth0を使用してパケットを送出するという意味です。  
proto kernel はカーネルによってルート情報が作成されたことを示しています。  
scope link はデータリンク上に直接パケットを送出するという意味です。  
src 172.18.0.1 は 172.18.0.1 というIPアドレスを使用してパケットを送出するという意味です。  
しかし、10.0.0.0/24 へのルート情報はルーティングテーブルに登録されていません。  
ここでルーティングテーブルに 10.0.0.0/24 へのルート情報を登録してpingを送ってみましょう。

    [nodeA]
    nodeA# ip route add 10.0.0.0/24 via 172.18.0.1
    nodeA# ping 10.0.0.1
    ^C

返答がありません。これはたとえnodeBにpingパケットが届いたとしてもnodeBがnodeAへのルート情報を登録していないため返答をすることができないからです。  
nodeBへパケットが届いているか否かはnodeBでパケットキャプチャをすることで確認できます。

    [nodeB]
    nodeB# tcpdump -ln# icmp                      
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on veth0, link-type EN10MB (Ethernet), capture size 262144 bytes
        1  22:06:23.930002 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 1, length 64
        2  22:06:24.946273 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 2, length 64
        3  22:06:25.970002 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 3, length 64
        4  22:06:26.994276 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 4, length 64
    ^C
    4 packets captured
    4 packets received by filter
    0 packets dropped by kernel

もし届いていなければルータ側で次の設定をしてみてください。

    [rt]
    rt# sysctl -w net.ipv4.ip_forward=1
    net.ipv4.ip_forward = 1

これでルータでIPパケットフォワーディング(IPパケット転送)ができるはずです。

さて、nodeBが返答を送信するためにはnodeBに172.18.0.0/24へのルート情報を登録します。
このようにすると、nodeAからnodeBへのpingが疎通します。

    [nodeB]
    nodeB# ip route add 172.18.0.0/24 via 10.0.0.254

    [nodeA]
    nodeA# ping 10.0.0.1
    PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
    64 bytes from 10.0.0.1: icmp_seq=1 ttl=63 time=0.077 ms
    64 bytes from 10.0.0.1: icmp_seq=2 ttl=63 time=0.072 ms
    64 bytes from 10.0.0.1: icmp_seq=3 ttl=63 time=0.073 ms
    64 bytes from 10.0.0.1: icmp_seq=4 ttl=63 time=0.072 ms
    ^C
    --- 10.0.0.1 ping statistics ---
    4 packets transmitted, 4 received, 0% packet loss, time 3068ms
    rtt min/avg/max/mdev = 0.072/0.073/0.077/0.002 ms

当然、ノードを接続したスイッチをルータに接続しても、違うセグメント間でパケットを疎通できます。  
それを説明するために一旦作成したノードを削除しましょう。

    $ ./rmcontainer.sh rt nodeA nodeB

さて、ここで仮想ネットワークにセグメントA(172.18.1.0/24)とセグメントB(172.18.2.0/24)を作成しましょう。  
セグメントAにはnodeA1, nodeA2, nodeA3, rt0が属しており、セグメントBにはnodeB1, nodeB2, rt0が属しているとします。  
そのセグメントAの全ノードにセグメントBへのルートを、セグメントBの全ノードにセグメントBへのルートを設定します。

    $ ./mkcontainer.sh node rt0 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2
    $ ./ctl2net.sh setup brA nodeA1 172.18.1.1/24 nodeA2 172.18.1.2/24 nodeA3 172.18.1.3/24 rt0 172.18.1.254/24
    $ ./ctl2net.sh setup brB nodeB1 172.18.2.1/24 nodeB2 172.18.2.2/24 rt0 172.18.2.254/24
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 172.18.2.0/24 via 172.18.1.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 172.18.1.0/24 via 172.18.2.254; done

これによって、例えばnodeA1からnodeB1, nodeB2へ、nodeB1からnodeA1, nodeA2, nodeA3へとpingを送ることができるようになりました。

そのように手動で設定したルート情報をスタティックルート(静的ルート)と呼びます。  
今回は簡単なネットワーク構成でしたからスタティックルートの設定もあまり大変ではありませんでしたが、
ネットワーク構成が複雑になればなるほどルート情報の設定が大変になります。

例えば次のようなネットワーク構成があるとします。

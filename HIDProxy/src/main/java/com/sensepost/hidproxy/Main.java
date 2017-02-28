package com.sensepost.hidproxy;

import java.io.File;
import java.net.InetSocketAddress;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerAdapter;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.ChannelPromise;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.oio.OioEventLoopGroup;
import io.netty.channel.socket.SocketChannel;
import io.netty.channel.socket.nio.NioServerSocketChannel;

public class Main {

	static final int PORT = Integer.parseInt(System.getProperty("port", "65534"));
	static final String INTERFACE = System.getProperty("interface", "0.0.0.0");
	static final String PAYLOAD0 = System.getProperty("payload", "../powershell/Proxy.ps1");
	static final String TARGET = System.getProperty("target", "localhost:65535");

	public static void main(String[] args) throws Exception {
		InetSocketAddress listenAddr = new InetSocketAddress(INTERFACE, PORT);
		int colon = TARGET.indexOf(':');
		InetSocketAddress target = new InetSocketAddress(TARGET.substring(0, colon),
				Integer.parseInt(TARGET.substring(colon + 1)));

		EventLoopGroup bossGroup = new NioEventLoopGroup(1);
		EventLoopGroup workerGroup = new NioEventLoopGroup();
		try {
			File payload0 = new File(PAYLOAD0);
			if (!payload0.canRead()) {
				System.err.println("Cannot read " + payload0);
				System.exit(0);
			}
			ServerBootstrap b = new ServerBootstrap();
			b.group(bossGroup, workerGroup).channel(NioServerSocketChannel.class)
					.childHandler(new MuxInitializer(target, payload0));
			Channel c = b.bind(listenAddr).sync().channel();
			System.out.println("Listening on " + listenAddr + "\n" + "Connections will be relayed to " + target
					+ "\nPress Enter to shutdown");
			System.in.read();
			System.out.print("Exiting...");
			ChannelFuture f = c.closeFuture();
			c.close();
			f.sync();
			System.out.println("Done");
		} finally {
			bossGroup.shutdownGracefully();
			workerGroup.shutdownGracefully();
		}
	}

	private static class MuxInitializer extends ChannelInitializer<SocketChannel> {

		private InetSocketAddress target;
		private File payload0;

		public MuxInitializer(InetSocketAddress target, File payload0) {
			this.target = target;
			this.payload0 = payload0;
		}

		@Override
		public void initChannel(SocketChannel ch) throws Exception {
			ch.pipeline().addLast(new PacketCodec(65), new MuxHandler(target, payload0));
		}
	}

	public static final class MuxHandler extends ChannelHandlerAdapter {
		private InetSocketAddress target;
		private File payload0;

		private Channel[] conns = new Channel[256];

		public MuxHandler(InetSocketAddress target, File payload0) {
			this.target = target;
			this.payload0 = payload0;
		}

		@Override
		public void channelActive(ChannelHandlerContext ctx) throws Exception {
			System.err.println("Connection received from " + ctx.channel().remoteAddress());
		}

		@Override
		public void channelInactive(ChannelHandlerContext ctx) throws Exception {
			System.err.println("Connection from " + ctx.channel().remoteAddress() + " closed!");
			for (int i = 0; i < conns.length; i++) {
				if (conns[i] != null) {
					conns[i].close();
					conns[i] = null;
				}
			}
		}

		private Packet makeResetPacket(Packet p) {
			Packet response = new Packet();
			response.setFlags(Packet.RST | Packet.ACK);
			response.setChannel(p.getChannel());
			response.setAck(p.getSeq() + 1);
			return response;
		}

		@Override
		public void channelRead(final ChannelHandlerContext ctx, Object msg) {
			// System.out.println("R: " + msg);
			if (!(msg instanceof Packet)) {
				System.err.println("Unexpected object received: " + msg);
				return;
			}
			final Packet p = (Packet) msg;
			final int c = p.getChannel();

			if (p.getFlags() == Packet.SYN) {
				if (conns[c] != null) { // SYN on existing channel!
					// For the moment, let's discard the existing state
					conns[c].close();
				}
				ChannelFuture f;
				Bootstrap b = new Bootstrap().handler(new HIDProxyBackendInitializer(ctx.channel(), c))
						.option(ChannelOption.AUTO_READ, false);
				if (c == 0) {
					b.group(new OioEventLoopGroup()).channel(FileChannel.class);
					FileAddress fa = new FileAddress(payload0);
					f = b.connect(fa);
				} else {
					// Start the connection attempt.
					b.group(ctx.channel().eventLoop()).channel(ctx.channel().getClass());
					f = b.connect(target);
				}
				f.addListener(new ChannelFutureListener() {
					@Override
					public void operationComplete(ChannelFuture future) {
						if (future.isSuccess()) {
							conns[c] = future.channel();
							future.channel().writeAndFlush(p);
						} else {
							conns[c] = null;
							future.cause().printStackTrace();
							// Close the connection if the connection
							// attempt has failed.
							ctx.channel().writeAndFlush(makeResetPacket(p));
						}
					}
				});
			} else if (conns[c] != null) {
				conns[c].writeAndFlush(p);
			}
		}

		@Override
		public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
			// System.out.println("W: " + msg);
			super.write(ctx, msg, promise);
		}
	}

	private static class HIDProxyBackendInitializer extends ChannelInitializer<Channel> {
		private Channel inboundChannel;
		private int channel;

		public HIDProxyBackendInitializer(Channel inboundChannel, int channel) {
			this.inboundChannel = inboundChannel;
			this.channel = channel;
		}

		@Override
		protected void initChannel(Channel ch) throws Exception {
			ch.pipeline().addLast(new ChunkedFrameDecoder(60), new TCPCodec(inboundChannel, channel));
		}

	}

}

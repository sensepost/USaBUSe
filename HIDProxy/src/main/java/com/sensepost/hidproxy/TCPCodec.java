package com.sensepost.hidproxy;

import java.io.IOException;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.Channel;
import io.netty.channel.ChannelHandlerAdapter;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelPromise;

public class TCPCodec extends ChannelHandlerAdapter {
		private Channel inbound;
		private int channel, rcvSeq = 0;
		private volatile int sendSeq = 0, sendUnack = 1;
		private long timestamp = System.currentTimeMillis();
		private int bytes_read = 0, bytes_written = 0;

		public TCPCodec(Channel inbound, int channel) {
			this.inbound = inbound;
			this.channel = channel;
		}

		@Override
		public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
			if (!(msg instanceof ByteBuf)) {
				System.err.println("Unexpected object: " + msg);
				return;
			}
			ByteBuf buf = (ByteBuf) msg;
			if (buf.readableBytes() > 60)
				throw new IOException("Packet too large: " + buf.readableBytes() + " bytes!");

			byte[] data = new byte[Math.min(60, buf.readableBytes())];
			buf.readBytes(data);
			bytes_read += data.length;
			long now = System.currentTimeMillis();
			if (now - timestamp > 1000) {
				System.err.println("Channel " + channel + ", read " + bytes_read + ", written " + bytes_written);
				timestamp = now;
			}
			inbound.writeAndFlush(makePacket(Packet.ACK, data, data.length));
		}

		private Packet makePacket(int flags, byte[] data, int length) {
			if ((flags & Packet.SYN) == Packet.SYN || (flags & Packet.FIN) == Packet.FIN || length > 0)
				sendSeq++;

			Packet p = new Packet();
			p.setChannel(channel);
			p.setFlags(flags);
			p.setSeq(sendSeq);
			p.setAck(rcvSeq + 1);
			p.setData(data, 0, length);
			return p;
		}


		@Override
		public void channelInactive(ChannelHandlerContext ctx) throws Exception {
			inbound.writeAndFlush(makePacket(Packet.FIN, null, 0));
			super.channelInactive(ctx);
		}

		@Override
		public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
//			System.err.println("Receive: ctx=" + ctx + ", msg = " + msg);
			if (!(msg instanceof Packet)) {
				System.err.println("Unexpected object: " + msg);
				return;
			}
			Packet p = (Packet) msg;
			int flags = p.getFlags();
			if (flags == Packet.SYN) {
				rcvSeq = p.getSeq();
				inbound.writeAndFlush(makePacket(Packet.SYN | Packet.ACK, null, 0));
				return;
			} else if (flags == (Packet.SYN | Packet.ACK)) {
				// response to us sending a SYN, not implemented yet // FIXME
			} else if (flags == Packet.ACK) {
				if (p.getAck() == ((sendUnack + 1) & 0xF)) {
					sendUnack++;
				}
				ctx.channel().read(); // only once the SYN/ACK is complete
				if (p.getSeq() == (rcvSeq & 0xF)) {
					// no data
				} else if (p.getSeq() == ((rcvSeq + 1) & 0xF)) {
					rcvSeq++;
					byte[] data = p.getData();
					if (data.length > 0) {
						super.write(ctx, Unpooled.wrappedBuffer(data), promise);
						bytes_written += data.length;
						long now = System.currentTimeMillis();
						if (now - timestamp > 1000) {
							System.err.println("Channel " + channel + ", read " + bytes_read + ", written " + bytes_written);
							timestamp = now;
						}
					}
					inbound.writeAndFlush(makePacket(Packet.ACK, null, 0));
				} else {
					System.err.println("Received packet out of order!\n" + this + "\n" + p);
				}
			} else if (flags == Packet.FIN) {
				if (p.getAck() == ((sendUnack + 1) & 0xF)) {
					sendUnack++;
				}
				if (p.getSeq() == (rcvSeq & 0xF)) {
					// no data
				} else if (p.getSeq() == ((rcvSeq + 1) & 0xF)) {
					rcvSeq++;
					inbound.writeAndFlush(makePacket(Packet.FIN | Packet.ACK, null, 0));
				} else {
					System.err.println("Received packet out of order!\n" + this + "\n" + p);
				}
			}
		}

	}
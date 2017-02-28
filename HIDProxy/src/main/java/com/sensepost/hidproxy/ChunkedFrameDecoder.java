package com.sensepost.hidproxy;

import java.util.List;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.MessageToMessageDecoder;

class ChunkedFrameDecoder extends MessageToMessageDecoder<ByteBuf> {

	/**
	 * Splits data read from the upstream Channel into *size*-byte chunks, to
	 * be formatted into Packets, and subsequently written out over the
	 * multiplexed Channel
	 */
	private int size;

	public ChunkedFrameDecoder(int size) {
		this.size = size;
	}

	@Override
	protected void decode(ChannelHandlerContext ctx, ByteBuf buf, List<Object> out) throws Exception {
		while (buf.readableBytes() > 0) {
			out.add(buf.readSlice(Math.min(buf.readableBytes(), size)).retain());
		}
	}

}
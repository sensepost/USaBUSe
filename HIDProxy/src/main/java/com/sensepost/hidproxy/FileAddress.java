package com.sensepost.hidproxy;

import java.io.File;
import java.net.SocketAddress;

class FileAddress extends SocketAddress {
	private static final long serialVersionUID = -5998247210173326653L;

	private File file;

	public FileAddress(File file) {
		this.file = file;
	}

	public File file() {
		return file;
	}
}